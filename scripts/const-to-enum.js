#!/usr/bin/env node

const fs = require('fs');
const yaml = require('js-yaml');

/**
 * Recursively processes an object to convert const properties to single-value enum arrays.
 * 
 * @param {any} obj - The object to process
 * @returns {any} - The processed object
 */
function processConst(obj) {
  // Handle null or primitive values
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }

  // Handle arrays
  if (Array.isArray(obj)) {
    return obj.map(item => processConst(item));
  }

  // Handle objects
  const processed = {};
  let hasConst = false;
  let constValue = null;
  
  for (const [key, value] of Object.entries(obj)) {
    if (key === 'const') {
      hasConst = true;
      constValue = value;
      // Don't add 'const' to the processed object yet
    } else {
      // Recursively process nested objects and arrays
      processed[key] = processConst(value);
    }
  }

  // If this object had a 'const' property, convert it to 'enum'
  if (hasConst) {
    processed['enum'] = [constValue];
  }

  return processed;
}

/**
 * Main function to process the OpenAPI YAML file
 */
function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage: node const-to-enum.js <input.yaml> [output.yaml]');
    console.error('');
    console.error('If output.yaml is not specified, the result will be printed to stdout.');
    process.exit(1);
  }

  const inputFile = args[0];
  const outputFile = args[1];

  // Read the input YAML file
  let yamlContent;
  try {
    yamlContent = fs.readFileSync(inputFile, 'utf8');
  } catch (error) {
    console.error(`Error reading file ${inputFile}:`, error.message);
    process.exit(1);
  }

  // Parse the YAML
  let parsedYaml;
  try {
    parsedYaml = yaml.load(yamlContent);
  } catch (error) {
    console.error('Error parsing YAML:', error.message);
    process.exit(1);
  }

  // Process the parsed YAML
  const processedYaml = processConst(parsedYaml);

  // Convert back to YAML
  const outputYaml = yaml.dump(processedYaml, {
    indent: 2,
    lineWidth: -1, // Don't wrap lines
    noRefs: true,  // Don't use anchors/references
  });

  // Write to output file or stdout
  if (outputFile) {
    try {
      fs.writeFileSync(outputFile, outputYaml, 'utf8');
      console.log(`Successfully processed ${inputFile} -> ${outputFile}`);
    } catch (error) {
      console.error(`Error writing file ${outputFile}:`, error.message);
      process.exit(1);
    }
  } else {
    console.log(outputYaml);
  }
}

// Run the script if executed directly
if (require.main === module) {
  main();
}

module.exports = { processConst };