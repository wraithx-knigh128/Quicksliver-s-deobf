'use strict';

const scopes = require('../beautify/scopes');
const shapes = require('../beautify/shapes');

function run(context) {
  shapes.flatten(context.chunk);
  context.resolve();
  const wrapped = scopes.fit(context.chunk, () => context.resolve());
  shapes.flatten(context.chunk);
  if (wrapped) {
    context.note(`narrowed ${wrapped} scope(s) to fit the local limit`, wrapped);
    context.bump('scope.narrowed', wrapped);
  }
}

module.exports = {
  name: '11-scope',
  run,
};
