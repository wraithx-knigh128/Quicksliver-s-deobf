'use strict';

const { AstWalker } = require('../../ast/visitors/AstWalker.js');
const N = require('../../ast/Nodes.js');

class StringCollector extends AstWalker {
    constructor() {
        super();
        this.strings = [];
    }

    visitCall(node) {
        if (node.arguments.length === 2
            && node.arguments[0] instanceof N.NumberLiteral
            && node.arguments[1] instanceof N.StringLiteral) {
            this.strings.push([Math.trunc(node.arguments[0].value), node.arguments[1].value.slice(1, -1)]);
        }

        super.visitCall(node);
    }

    visitStringLiteral(node) {
        const value = node.value;

        if (value.startsWith('"\\4\\8')) {
            this.strings.push([null, value.slice(1, -1)]);
        }
    }

    static collect(node) {
        const walker = new StringCollector();
        walker.visit(node);
        return walker.strings;
    }
}

module.exports = { StringCollector };