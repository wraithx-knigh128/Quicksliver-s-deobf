'use strict';

const N = require('../ast/Nodes.js');

class VariableInfo {
    constructor() {
        this.value = undefined;
        this.declarationLocation = undefined;
        this.assignmentCount = 0;
        this.readCount = 0;
    }
}

class SymbolTable {
    constructor() {
        this.variables = new Map();
    }

    define(name, info) {
        this.variables.set(name, info);
    }

    isDefined(name) {
        return this.variables.has(name);
    }

    getVariable(name) {
        return this.variables.get(name);
    }
}

class SymbolTableBuilder {
    static build(node) {
        const visitor = {
            symbols: new SymbolTable(),

            visit(node) {
                if (node === null || node === undefined) {
                    return;
                }

                switch (node.constructor) {
                    case N.Name:
                        return this.visitName(node);
                    case N.LocalDeclare:
                        return this.visitLocalDeclare(node);
                    case N.Assign:
                        return this.visitAssign(node);
                    case N.ParameterList:
                        return this.visitParameterList(node);
                    case N.Function:
                        return this.visitFunction(node);
                    case N.LocalFunction:
                        return this.visitLocalFunction(node);
                    case N.NumericFor:
                        return this.visitNumericFor(node);
                    case N.GenericFor:
                        return this.visitGenericFor(node);
                    case N.Block:
                        for (const statement of node.statements) {
                            this.visit(statement);
                        }
                        return;
                    case N.AnonymousFunction:
                    case N.While:
                    case N.Do:
                    case N.Repeat:
                        for (const child of node.childNodes()) {
                            this.visit(child);
                        }
                        return;
                    default:
                        for (const child of node.childNodes()) {
                            this.visit(child);
                        }
                }
            },

            visitName(node) {
                const info = this.symbols.getVariable(node.value);
                if (info !== undefined) {
                    info.readCount++;
                }
            },

            visitLocalDeclare(node) {
                this.visitList(node.values);
                for (let i = 0; i < node.names.length; i++) {
                    const name = node.names[i].value;
                    const expression = i < node.values.length
                        ? node.values[i]
                        : node.values[node.values.length - 1];

                    this.symbols.define(name, {
                        value: expression,
                        declarationLocation: node,
                        assignmentCount: 0,
                        readCount: 0
                    });
                }
            },

            visitAssign(node) {
                this.visitList(node.values);
                for (let i = 0; i < node.variables.length; i++) {
                    const variable = node.variables[i];

                    if (!(variable instanceof N.Name)) {
                        this.visit(variable);
                        continue;
                    }

                    const value = variable.value;
                    const expression = i < node.values.length
                        ? node.values[i]
                        : node.values[node.values.length - 1];

                    if (this.symbols.isDefined(value)) {
                        const info = this.symbols.getVariable(value);
                        const newInfo = Object.assign(new VariableInfo(), info);
                        newInfo.value = undefined;
                        newInfo.assignmentCount++;
                        this.symbols.define(value, newInfo);
                    } else {
                        this.symbols.define(value, {
                            value: expression,
                            declarationLocation: node,
                            assignmentCount: 0,
                            readCount: 0
                        });
                    }
                }
            },

            visitParameterList(node) {
                for (const name of node.names) {
                    this.symbols.define(name.value, {
                        declarationLocation: node,
                        assignmentCount: 0,
                        readCount: 0,
                        value: undefined
                    });
                }
            },

            visitFunction(node) {
                this.symbols.define(node.name.value, {
                    declarationLocation: node,
                    assignmentCount: 0,
                    readCount: 0,
                    value: undefined
                });
                this.visit(node.parameters);
                this.visit(node.body);
            },

            visitLocalFunction(node) {
                this.symbols.define(node.name.value, {
                    declarationLocation: node,
                    assignmentCount: 0,
                    readCount: 0,
                    value: undefined
                });
                this.visit(node.parameters);
                this.visit(node.body);
            },

            visitNumericFor(node) {
                this.visit(node.initialValue);
                this.visit(node.finalValue);
                if (node.step !== null) {
                    this.visit(node.step);
                }
                this.symbols.define(node.iteratorName.value, {
                    declarationLocation: node,
                    assignmentCount: 0,
                    readCount: 0,
                    value: undefined
                });
                this.visit(node.body);
            },

            visitGenericFor(node) {
                this.visitList(node.expressions);
                for (const name of node.names) {
                    this.symbols.define(name.value, {
                        declarationLocation: node,
                        assignmentCount: 0,
                        readCount: 0,
                        value: undefined
                    });
                }
                this.visit(node.body);
            },

            visitList(list) {
                for (const node of list) {
                    this.visit(node);
                }
            }
        };

        visitor.visit(node);
        return visitor.symbols;
    }
}

module.exports = { SymbolTable, VariableInfo, SymbolTableBuilder };