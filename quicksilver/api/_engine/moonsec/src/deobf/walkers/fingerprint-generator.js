'use strict';

const { AstWalker } = require('../../ast/visitors/AstWalker.js');
const { BinaryOperator, UnaryOperator } = require('../../ast/Operators.js');
const N = require('../../ast/Nodes.js');

const Operation = Object.freeze({
    InstRef: 0,
    StkRef: 1,
    UpvRef: 2,
    EnvRef: 3,
    VarArgRef: 4,
    UnpackRef: 5,
    InsertRef: 6,
    SetMetatableRef: 7,
    WrapProtoRef: 8,
    Access: 9,
    If: 10,
    ElseIf: 11,
    Else: 12,
    For: 13,
    Call: 14,
    Add: 15,
    Sub: 16,
    Mul: 17,
    Div: 18,
    Mod: 19,
    Pow: 20,
    LessThan: 21,
    GreaterThan: 22,
    LessThanOrEquals: 23,
    GreaterThanOrEquals: 24,
    Equals: 25,
    NotEquals: 26,
    Return: 27,
    Len: 28,
    PcRef: 29,
    TopRef: 30,
    Negate: 31,
    Concat: 32,
    Table: 33,
    Not: 34,
    And: 35,
    Or: 36
});

class FingerprintGenerator extends AstWalker {
    constructor() {
        super();
        this.operations = [];
    }

    visitName(node) {
        switch (node.value) {
            case 'stk':
                this.operations.push(Operation.StkRef);
                break;
            case 'env':
                this.operations.push(Operation.EnvRef);
                break;
            case 'upv':
                this.operations.push(Operation.UpvRef);
                break;
            case 'inst':
                this.operations.push(Operation.InstRef);
                break;
            case 'vararg':
                this.operations.push(Operation.VarArgRef);
                break;
            case 'unpack':
                this.operations.push(Operation.UnpackRef);
                break;
            case 'setmetatable':
                this.operations.push(Operation.SetMetatableRef);
                break;
            case 'pc':
                this.operations.push(Operation.PcRef);
                break;
            case 'top':
                this.operations.push(Operation.TopRef);
                break;
            case 'wrap_proto':
                this.operations.push(Operation.WrapProtoRef);
                break;
        }
    }

    visitMemberAccess(node) {
        if (node.table instanceof N.Name && node.table.value === 'table' && node.key.value === 'insert') {
            this.operations.push(Operation.InsertRef);
        } else {
            this.operations.push(Operation.Access);
        }

        super.visitMemberAccess(node);
    }

    visitElementAccess(node) {
        this.operations.push(Operation.Access);
        super.visitElementAccess(node);
    }

    visitIf(node) {
        this.operations.push(Operation.If);

        for (let i = 0; i < node.elseIfClauses.length; i++) {
            this.operations.push(Operation.ElseIf);
        }

        if (node.elseBody !== null) {
            this.operations.push(Operation.Else);
        }

        super.visitIf(node);
    }

    visitNumericFor(node) {
        this.operations.push(Operation.For);
        super.visitNumericFor(node);
    }

    visitCall(node) {
        this.operations.push(Operation.Call);
        super.visitCall(node);
    }

    visitMethodCall(node) {
        this.operations.push(Operation.Call);
        super.visitMethodCall(node);
    }

    visitBinaryExpression(node) {
        switch (node.operator) {
            case BinaryOperator.Add:
                this.operations.push(Operation.Add);
                break;
            case BinaryOperator.Sub:
                this.operations.push(Operation.Sub);
                break;
            case BinaryOperator.Mul:
                this.operations.push(Operation.Mul);
                break;
            case BinaryOperator.Div:
                this.operations.push(Operation.Div);
                break;
            case BinaryOperator.Mod:
                this.operations.push(Operation.Mod);
                break;
            case BinaryOperator.Pow:
                this.operations.push(Operation.Pow);
                break;
            case BinaryOperator.LessThan:
                this.operations.push(Operation.LessThan);
                break;
            case BinaryOperator.LessThanOrEquals:
                this.operations.push(Operation.LessThanOrEquals);
                break;
            case BinaryOperator.GreaterThan:
                this.operations.push(Operation.GreaterThan);
                break;
            case BinaryOperator.GreaterThanOrEquals:
                this.operations.push(Operation.GreaterThanOrEquals);
                break;
            case BinaryOperator.Equals:
                this.operations.push(Operation.Equals);
                break;
            case BinaryOperator.NotEquals:
                this.operations.push(Operation.NotEquals);
                break;
            case BinaryOperator.Concat:
                this.operations.push(Operation.Concat);
                break;
            case BinaryOperator.And:
                this.operations.push(Operation.And);
                break;
            case BinaryOperator.Or:
                this.operations.push(Operation.Or);
                break;
        }

        super.visitBinaryExpression(node);
    }

    visitUnaryExpression(node) {
        switch (node.operator) {
            case UnaryOperator.Length:
                this.operations.push(Operation.Len);
                break;
            case UnaryOperator.Negate:
                this.operations.push(Operation.Negate);
                break;
            case UnaryOperator.Not:
                this.operations.push(Operation.Not);
                break;
        }

        super.visitUnaryExpression(node);
    }

    visitReturn(node) {
        this.operations.push(Operation.Return);
        super.visitReturn(node);
    }

    visitTable(node) {
        this.operations.push(Operation.Table);
        super.visitTable(node);
    }

    static generate(node) {
        const walker = new FingerprintGenerator();
        walker.visit(node);
        return walker.operations.map(op => op).join('');
    }
}

module.exports = { FingerprintGenerator };