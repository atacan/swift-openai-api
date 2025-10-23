#!/usr/bin/env node

// Run with `node generate_overlay_for_multipart_required.js [input-file]`
// Supports both JSON and YAML formats
const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

// Get input file from command line argument or use default
const inputFile = process.argv[2] || '../openapi.yaml';
const openApiPath = path.join(__dirname, inputFile);

// Check if file exists
if (!fs.existsSync(openApiPath)) {
    console.error(`Error: File not found: ${openApiPath}`);
    process.exit(1);
}

// Determine file format based on extension
const ext = path.extname(openApiPath).toLowerCase();
const isYaml = ext === '.yaml' || ext === '.yml';
const isJson = ext === '.json';

if (!isYaml && !isJson) {
    console.error(`Error: Unsupported file format: ${ext}. Expected .json, .yaml, or .yml`);
    process.exit(1);
}

// Read and parse the OpenAPI spec
console.log(`Reading OpenAPI spec from: ${openApiPath} (${isYaml ? 'YAML' : 'JSON'} format)`);
const fileContent = fs.readFileSync(openApiPath, 'utf8');
const openApiSpec = isYaml ? yaml.load(fileContent) : JSON.parse(fileContent);

// Function to find all multipart/form-data request bodies without required: true
function findMultipartRequestBodiesWithoutRequired(paths) {
    const missingRequiredBodies = [];
    
    for (const [pathName, pathObj] of Object.entries(paths)) {
        for (const [method, methodObj] of Object.entries(pathObj)) {
            if (methodObj.requestBody && methodObj.requestBody.content) {
                const content = methodObj.requestBody.content;
                
                // Check if this has multipart/form-data content
                if (content['multipart/form-data']) {
                    const requestBody = methodObj.requestBody;
                    
                    // Check if required is missing or false
                    if (requestBody.required !== true) {
                        const currentPath = ['paths', pathName, method, 'requestBody'];
                        const jsonPath = '$.' + currentPath.join('.');
                        
                        missingRequiredBodies.push({
                            path: currentPath.join('.'),
                            jsonPath: jsonPath,
                            pathName: pathName,
                            method: method.toUpperCase(),
                            operationId: methodObj.operationId || `${method}_${pathName}`,
                            currentRequired: requestBody.required,
                            requestBody: requestBody
                        });
                    }
                }
            }
        }
    }
    
    return missingRequiredBodies;
}

// Find all multipart request bodies without required: true
console.log('Scanning OpenAPI spec for multipart/form-data request bodies without required: true...');
const missingRequiredBodies = findMultipartRequestBodiesWithoutRequired(openApiSpec.paths || {});

console.log(`Found ${missingRequiredBodies.length} multipart request bodies without required: true:`);
missingRequiredBodies.forEach(body => {
    console.log(`  - ${body.method} ${body.pathName} (${body.operationId})`);
    console.log(`    Current required: ${body.currentRequired}`);
});

// Generate overlay actions
const overlayActions = [];

missingRequiredBodies.forEach(body => {
    // Create the updated request body with required: true
    const updatedRequestBody = {
        ...body.requestBody,
        required: true
    };
    
    // Add update action
    overlayActions.push({
        target: body.jsonPath,
        update: updatedRequestBody
    });
});

// Create the complete overlay
const overlay = {
    "overlay": "1.0.0",
    "info": {
        "title": "Fix OpenAPI spec - Add required: true to multipart/form-data request bodies",
        "version": "1.0.0"
    },
    "actions": overlayActions
};

// Write the overlay file in the same format as the input
const overlayExt = isYaml ? '.yaml' : '.json';
const overlayPath = path.join(__dirname, `overlay_generated_for_multipart_required${overlayExt}`);

const overlayContent = isYaml
    ? yaml.dump(overlay, { indent: 2, lineWidth: -1 })
    : JSON.stringify(overlay, null, 2);

fs.writeFileSync(overlayPath, overlayContent);

console.log(`\nGenerated overlay with ${overlayActions.length} actions`);
console.log(`Overlay saved to: ${overlayPath}`);

if (overlayActions.length > 0) {
    console.log('\nSample of generated actions:');
    if (isYaml) {
        console.log(yaml.dump(overlay.actions.slice(0, 2), { indent: 2, lineWidth: -1 }));
    } else {
        console.log(JSON.stringify(overlay.actions.slice(0, 2), null, 2));
    }

    console.log('\nTo apply this overlay, run:');
    const outputFormat = isYaml ? 'yaml' : 'json';
    const outputExt = isYaml ? '.yaml' : '.json';
    console.log(`npx @apidevtools/swagger-parser bundle -o openapi_fixed${outputExt} -t ${outputFormat} overlay_generated_for_multipart_required${overlayExt} ${inputFile}`);
}
