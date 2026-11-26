'use strict';

const luaparse = require('luaparse');
const { NodeList } = require('../ast/NodeList.js');
const { BinaryOperator, UnaryOperator } = require('../ast/Operators.js');
const N = require('../ast/Nodes.js');

function toNames(list) {
    return NodeList.of(...list.map(node => node instanceof N.Name ? node : new N.Name(node.name)));
}

function toExprList(list) {
    return NodeList.of(...list.map(convertExpression));
}

function convertExpression(node) {
    switch (node.type) {
        case 'Identifier':
            return new N.Name(node.name);

        case 'StringLiteral':
            return new N.StringLiteral(node.raw);

        case 'NumericLiteral':
            return new N.NumberLiteral(node.value);

        case 'BooleanLiteral':
            return new N.BooleanLiteral(node.value);

        case 'NilLiteral':
            return new N.Nil();

        case 'VarargLiteral':
            return new N.VarArg();

        case 'IndexExpression':
            return new N.ElementAccess(convertExpression(node.base), convertExpression(node.index));

        case 'MemberExpression': {
            const table = convertExpression(node.base);
            return new N.MemberAccess(table, new N.Name(node.identifier.name));
        }

        case 'CallExpression': {
            if (node.base.type === 'MemberExpression' && node.base.indexer === ':') {
                const table = convertExpression(node.base.base);
                return new N.MethodCall(table, new N.Name(node.base.identifier.name), toExprList(node.arguments));
            }

            return new N.Call(convertExpression(node.base), toExprList(node.arguments));
        }

        case 'TableCallExpression': {
            const base = convertExpression(node.base);
            return new N.Call(base, NodeList.of(convertExpression(node.arguments)));
        }

        case 'StringCallExpression': {
            const base = convertExpression(node.base);
            return new N.Call(base, NodeList.of(convertExpression(node.argument)));
        }

        case 'BinaryExpression':
            return new N.BinaryExpression(binaryOperator(node.operator), convertExpression(node.left), convertExpression(node.right));

        case 'LogicalExpression': {
            const operator = node.operator === 'and' ? BinaryOperator.And : BinaryOperator.Or;
            return new N.BinaryExpression(operator, convertExpression(node.left), convertExpression(node.right));
        }

        case 'UnaryExpression':
            return new N.UnaryExpression(unaryOperator(node.operator), convertExpression(node.argument));

        case 'TableConstructorExpression': {
            const entries = node.fields.map(field => {
                if (field.type === 'TableKeyString') {
                    return new N.Table.Entry(new N.Name(field.key.name), convertExpression(field.value));
                }

                if (field.type === 'TableKey') {
                    return new N.Table.Entry(convertExpression(field.key), convertExpression(field.value));
                }

                return new N.Table.Entry(null, convertExpression(field.value));
            });

            return new N.Table(NodeList.of(...entries));
        }

        case 'FunctionDeclaration':
            return new N.AnonymousFunction(convertParameters(node.parameters, node), convertBlock(node.body));

        default:
            throw new Error(`Unhandled expression type: ${node.type}`);
    }
}

function binaryOperator(op) {
    switch (op) {
        case '+':
            return BinaryOperator.Add;
        case '-':
            return BinaryOperator.Sub;
        case '*':
            return BinaryOperator.Mul;
        case '/':
            return BinaryOperator.Div;
        case '%':
            return BinaryOperator.Mod;
        case '^':
            return BinaryOperator.Pow;
        case '==':
            return BinaryOperator.Equals;
        case '~=':
            return BinaryOperator.NotEquals;
        case '<':
            return BinaryOperator.LessThan;
        case '>':
            return BinaryOperator.GreaterThan;
        case '<=':
            return BinaryOperator.LessThanOrEquals;
        case '>=':
            return BinaryOperator.GreaterThanOrEquals;
        case '..':
            return BinaryOperator.Concat;
        default:
            throw new Error(`Unhandled binary operator: ${op}`);
    }
}

function unaryOperator(op) {
    switch (op) {
        case 'not':
            return UnaryOperator.Not;
        case '#':
            return UnaryOperator.Length;
        case '-':
            return UnaryOperator.Negate;
        default:
            throw new Error(`Unhandled unary operator: ${op}`);
    }
}

function convertParameters(parameters, node) {
    const names = new NodeList();
    let isVarArg = false;

    for (const parameter of parameters) {
        if (parameter.type === 'VarargLiteral') {
            isVarArg = true;
        } else {
            names.push(new N.Name(parameter.name));
        }
    }

    if (!isVarArg && node.isVararg) {
        isVarArg = true;
    }

    return new N.ParameterList(names, isVarArg);
}

function functionName(node) {
    if (node.identifier.type === 'Identifier') {
        return new N.Name(node.identifier.name);
    }

    const parts = [];
    let current = node.identifier;

    while (current.type !== 'Identifier') {
        parts.unshift(current.identifier.name);
        current = current.base;
    }

    parts.unshift(current.name);
    return new N.Name(parts.join('.'));
}

function convertStatement(node) {
    switch (node.type) {
        case 'LocalStatement':
            return new N.LocalDeclare(toNames(node.variables), toExprList(node.init));

        case 'AssignmentStatement':
            return new N.Assign(toExprList(node.variables), toExprList(node.init));

        case 'CallStatement':
            return new N.ExpressionStatement(convertExpression(node.expression));

        case 'IfStatement': {
            const clauses = node.clauses;

            const ifClause = new N.If.Clause(convertExpression(clauses[0].condition), convertBlock(clauses[0].body));

            const elseIfClauses = clauses
                .filter(clause => clause.type === 'ElseifClause')
                .map(clause => new N.If.Clause(convertExpression(clause.condition), convertBlock(clause.body)));

            const elseClause = clauses.find(clause => clause.type === 'ElseClause');
            const elseBody = elseClause ? convertBlock(elseClause.body) : null;

            return new N.If(ifClause, NodeList.of(...elseIfClauses), elseBody);
        }

        case 'WhileStatement':
            return new N.While(convertExpression(node.condition), convertBlock(node.body));

        case 'DoStatement':
            return new N.Do(convertBlock(node.body));

        case 'RepeatStatement':
            return new N.Repeat(convertBlock(node.body), convertExpression(node.condition));

        case 'ForNumericStatement':
            return new N.NumericFor(
                new N.Name(node.variable.name),
                convertExpression(node.start),
                convertExpression(node.end),
                node.step ? convertExpression(node.step) : null,
                convertBlock(node.body)
            );

        case 'ForGenericStatement':
            return new N.GenericFor(toNames(node.variables), toExprList(node.iterators), convertBlock(node.body));

        case 'ReturnStatement':
            return new N.Return(toExprList(node.arguments));

        case 'BreakStatement':
            return new N.Break();

        case 'GotoStatement':
            return new N.Goto(new N.Name(node.label));

        case 'LabelStatement':
            return new N.Label(new N.Name(node.label));

        case 'FunctionDeclaration': {
            const parameters = convertParameters(node.parameters, node);
            const body = convertBlock(node.body);

            if (node.isLocal) {
                return new N.LocalFunction(new N.Name(node.identifier.name), parameters, body);
            }

            return new N.Function(functionName(node), parameters, body);
        }

        default:
            throw new Error(`Unhandled statement type: ${node.type}`);
    }
}

function convertBlock(body) {
    const block = new N.Block();
    block.statements = NodeList.of(...body.map(convertStatement));
    return block;
}

function parseBlock(code) {
    const ast = luaparse.parse(code, { luaVersion: '5.3', ranges: false });
    return convertBlock(ast.body);
}

module.exports = { parseBlock, convertExpression, convertStatement };