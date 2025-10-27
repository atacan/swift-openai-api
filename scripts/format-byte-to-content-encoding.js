#!/usr/bin/env node

const fs = require('fs');
const yaml = require('js-yaml');

/**
 * Compares OpenAPI version to determine if it's 3.1.0 or higher
 * @param {string} version - The OpenAPI version string (e.g., "3.1.0")
 * @returns {boolean} - True if version is 3.1.0 or higher
 */
function isOpenAPI31OrHigher(version) {
  if (!version) return false;
  
  const parts = version.split('.').map(Number);
  const major = parts[0] || 0;
  const minor = parts[1] || 0;
  
  // Check if it's 3.1.x or higher
  if (major > 3) return true;
  if (major === 3 && minor >= 1) return true;
  
  return false;
}

/**
 * Recursively processes an object to convert format: byte to contentEncoding: base64
 * for string types when OpenAPI version is 3.1.0 or higher.
 * 
 * @param {any} obj - The object to process
 * @returns {any} - The processed object
 */
function processFormatByte(obj) {
  // Handle null or primitive values
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }

  // Handle arrays
  if (Array.isArray(obj)) {
    return obj.map(item => processFormatByte(item));
  }

  // Handle objects
  const processed = {};
  let hasStringType = false;
  let hasByteFormat = false;
  
  for (const [key, value] of Object.entries(obj)) {
    if (key === 'type' && value === 'string') {
      hasStringType = true;
      processed[key] = value;
    } else if (key === 'format' && value === 'byte') {
      hasByteFormat = true;
      // Don't add 'format: byte' to the processed object
    } else {
      // Recursively process nested objects and arrays
      processed[key] = processFormatByte(value);
    }
  }

  // If this object had both type: string and format: byte, convert to contentEncoding
  if (hasStringType && hasByteFormat) {
    processed['contentEncoding'] = 'base64';
  }

  return processed;
}

/**
 * Main function to process the OpenAPI YAML file
 */
function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage: node format-byte-to-content-encoding.js <input.yaml> [output.yaml]');
    console.error('');
    console.error('Converts format: byte to contentEncoding: base64 for OpenAPI 3.1.0+');
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

  // Check OpenAPI version
  const version = parsedYaml.openapi;
  
  if (!version) {
    console.error('Error: Could not find OpenAPI version in the document.');
    console.error('Make sure the document has an "openapi" field (e.g., "openapi: 3.1.0")');
    process.exit(1);
  }

  console.error(`Detected OpenAPI version: ${version}`);

  if (!isOpenAPI31OrHigher(version)) {
    console.error(`Warning: OpenAPI version ${version} is below 3.1.0.`);
    console.error('The format: byte syntax is valid for this version.');
    console.error('Skipping conversion. Use OpenAPI 3.1.0+ to apply this transformation.');
    
    // Output unchanged content
    if (outputFile) {
      fs.writeFileSync(outputFile, yamlContent, 'utf8');
      console.error(`File copied unchanged to ${outputFile}`);
    } else {
      console.log(yamlContent);
    }
    return;
  }

  console.error('Converting format: byte to contentEncoding: base64...');

  // Process the parsed YAML
  const processedYaml = processFormatByte(parsedYaml);

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
      console.error(`Successfully processed ${inputFile} -> ${outputFile}`);
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

module.exports = { processFormatByte, isOpenAPI31OrHigher };