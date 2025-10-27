const fs = require('fs');
const yaml = require('js-yaml');
const path = require('path');

/**
 * Recursively finds all schemas within an OpenAPI document and fixes the 'required' properties.
 * @param {object} obj The object to traverse.
 */
function fixRequiredProperties(obj) {
  if (typeof obj !== 'object' || obj === null) {
    return;
  }

  // Check if the current object is a schema with 'properties' and 'required'
  if (obj.hasOwnProperty('properties') && obj.hasOwnProperty('required') && Array.isArray(obj.required)) {
    const definedProperties = Object.keys(obj.properties);
    const originalRequiredCount = obj.required.length;

    obj.required = obj.required.filter(prop => definedProperties.includes(prop));

    const newRequiredCount = obj.required.length;

    if (newRequiredCount < originalRequiredCount) {
      console.log(`- Fixed a schema by removing ${originalRequiredCount - newRequiredCount} undefined required propert(ies).`);
    }
  }

  // Recurse into nested objects and arrays
  for (const key in obj) {
    if (obj.hasOwnProperty(key)) {
      fixRequiredProperties(obj[key]);
    }
  }
}

/**
 * Main function to read, process, and write the OpenAPI document.
 * @param {string} filePath The path to the OpenAPI document.
 */
function processOpenApiFile(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error(`Error: File not found at ${filePath}`);
    return;
  }

  const fileContent = fs.readFileSync(filePath, 'utf8');
  const fileExtension = path.extname(filePath).toLowerCase();

  let openApiDoc;

  try {
    if (fileExtension === '.yaml' || fileExtension === '.yml') {
      openApiDoc = yaml.load(fileContent);
    } else if (fileExtension === '.json') {
      openApiDoc = JSON.parse(fileContent);
    } else {
      console.error('Error: Unsupported file format. Please provide a .yaml, .yml, or .json file.');
      return;
    }
  } catch (e) {
    console.error(`Error parsing the OpenAPI document: ${e.message}`);
    return;
  }

  console.log(`Processing ${filePath}...`);
  fixRequiredProperties(openApiDoc);

  let outputContent;
  try {
    if (fileExtension === '.yaml' || fileExtension === '.yml') {
      outputContent = yaml.dump(openApiDoc);
    } else {
      outputContent = JSON.stringify(openApiDoc, null, 2);
    }
  } catch (e) {
    console.error(`Error serializing the updated OpenAPI document: ${e.message}`);
    return;
  }

  fs.writeFileSync(filePath, outputContent, 'utf8');
  console.log('Successfully updated the OpenAPI document!');
}

// Get the file path from the command line arguments
const filePath = process.argv[2];

if (!filePath) {
  console.error('Please provide the path to the OpenAPI document.');
  console.log('Usage: node fix-openapi.js <path-to-openapi-file>');
} else {
  processOpenApiFile(filePath);
}