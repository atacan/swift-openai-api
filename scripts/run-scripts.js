#!/usr/bin/env node

const { processAnyOf } = require('./cleanup-anyof-nulls.js');
const yaml = require('js-yaml');
const fs = require('fs');
const path = require('path');

console.log('Testing anyOf null cleanup...\n');

// Load the test input
const inputYaml = fs.readFileSync(path.join(__dirname, '../original.yaml'), 'utf8');
const parsedInput = yaml.load(inputYaml);

console.log('=== BEFORE ===');
console.log(yaml.dump(parsedInput.components.schemas.ResponseProperties, { indent: 2 }));

// Process the YAML
const processed = processAnyOf(parsedInput);

console.log('=== AFTER ===');
console.log(yaml.dump(processed.components.schemas.ResponseProperties, { indent: 2 }));

console.log('\n✓ Test completed successfully!');
console.log('\nTo process your own OpenAPI file, run:');
console.log('  node cleanup-anyof-nulls.js input.yaml output.yaml');