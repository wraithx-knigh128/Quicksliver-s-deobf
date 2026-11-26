'use strict';

const { AstWalker } = require('../../ast/visitors/AstWalker.js');

class Scope {
    constructor() {
        this.variables = new Map();
    }

    define(name, newName) {
        if (!this.variables.has(name)) {
            this.variables.set(name, []);
        }
        this.variables.get(name).push(newName);
    }

    isDefined(name) {
        return this.variables.has(name);
    }

    getNewName(name) {
        return this.variables.get(name)[this.variables.get(name).length - 1];
    }
}

class Renamer extends AstWalker {
    constructor(names) {
        super();
        this.names = names || {};
        this.scopes = [];
        this.counter = 0;
        this.pushScope();
    }

    pushScope() {
        const scope = new Scope();
        this.scopes.push(scope);
        return scope;
    }

    popScope() {
        this.scopes.pop();
    }

    renameAndDefine(scope, name) {
        const newName = Object.prototype.hasOwnProperty.call(this.names, name.value)
            ? this.names[name.value]
            : `_${this.counter++}`;
        scope.define(name.value, newName);
        name.value = newName;
    }

    visitLocalFunction(node) {
        this.renameAndDefine(this.scopes[this.scopes.length - 1], node.name);
        const scope = this.pushScope();

        for (const name of node.parameters.names) {
            this.renameAndDefine(scope, name);
        }

        this.visit(node.body);
        this.popScope();
    }

    visitFunction(node) {
        this.renameAndDefine(this.scopes[this.scopes.length - 1], node.name);
        const scope = this.pushScope();

        for (const name of node.parameters.names) {
            this.renameAndDefine(scope, name);
        }

        this.visit(node.body);
        this.popScope();
    }

    visitAnonymousFunction(node) {
        const scope = this.pushScope();

        for (const name of node.parameters.names) {
            this.renameAndDefine(scope, name);
        }

        this.visit(node.body);
        this.popScope();
    }

    visitGenericFor(node) {
        const scope = this.pushScope();

        for (const name of node.names) {
            this.renameAndDefine(scope, name);
        }

        this.visit(node.body);
        this.popScope();
    }

    visitNumericFor(node) {
        this.visit(node.initialValue);
        this.visit(node.finalValue);

        if (node.step !== null) {
            this.visit(node.step);
        }

        this.renameAndDefine(this.pushScope(), node.iteratorName);
        this.visit(node.body);
        this.popScope();
    }

    visitRepeat(node) {
        this.pushScope();
        this.visit(node.body);
        this.visit(node.condition);
        this.popScope();
    }

    visitWhile(node) {
        this.visit(node.condition);
        this.pushScope();
        this.visit(node.body);
        this.popScope();
    }

    visitDo(node) {
        this.pushScope();
        this.visit(node.body);
        this.popScope();
    }

    visitIf(node) {
        this.visit(node.ifClause);
        this.visitList(node.elseIfClauses);

        if (node.elseBody !== null) {
            this.pushScope();
            this.visit(node.elseBody);
            this.popScope();
        }
    }

    visitIfClause(node) {
        this.visit(node.condition);
        this.pushScope();
        this.visit(node.body);
        this.popScope();
    }

    visitLocalDeclare(node) {
        this.visitList(node.values);
        const scope = this.scopes[this.scopes.length - 1];

        for (const name of node.names) {
            this.renameAndDefine(scope, name);
        }
    }

    visitAssign(node) {
        this.visitList(node.values);
        this.visitList(node.variables);
    }

    visitName(node) {
        const value = node.value;

        for (let i = this.scopes.length - 1; i >= 0; i--) {
            const scope = this.scopes[i];

            if (!scope.isDefined(value)) {
                continue;
            }

            node.value = scope.getNewName(value);
            break;
        }
    }
}

module.exports = { Renamer };