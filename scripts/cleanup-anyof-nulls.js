#!/usr/bin/env node

const fs = require('fs');
const yaml = require('js-yaml');

/**
 * Recursively processes an object to remove null types from anyOf arrays
 * and simplifies anyOf when only one type remains.
 * 
 * @param {any} obj - The object to process
 * @returns {any} - The processed object
 */
function processAnyOf(obj) {
  // Handle null or primitive values
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }

  // Handle arrays
  if (Array.isArray(obj)) {
    return obj.map(item => processAnyOf(item));
  }

  // Handle objects
  const processed = {};
  
  for (const [key, value] of Object.entries(obj)) {
    if (key === 'anyOf' && Array.isArray(value)) {
      // Filter out null types from anyOf array
      const filteredArray = value.filter(item => {
        return !(item && typeof item === 'object' && item.type === 'null');
      });

      // If only one element remains, replace anyOf with that element
      if (filteredArray.length === 1) {
        const remainingElement = processAnyOf(filteredArray[0]);
        // Merge the remaining element properties into the parent object
        Object.assign(processed, remainingElement);
      } else if (filteredArray.length > 1) {
        // Keep anyOf if multiple elements remain
        processed[key] = filteredArray.map(item => processAnyOf(item));
      } else if (filteredArray.length === 0) {
        // If no elements remain, keep the original anyOf
        // (this shouldn't normally happen, but we handle it gracefully)
        processed[key] = value;
      }
    } else {
      // Recursively process nested objects and arrays
      processed[key] = processAnyOf(value);
    }
  }

  return processed;
}

/**
 * Main function to process the OpenAPI YAML file
 */
function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage: node cleanup-anyof-nulls.js <input.yaml> [output.yaml]');
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
  const processedYaml = processAnyOf(parsedYaml);

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

module.exports = { processAnyOf };