#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const yaml = require('yaml');

/**
 * OpenAPI Nullable Fixer
 * Converts OpenAPI 3.0.x nullable: true syntax to OpenAPI 3.1.0 compatible syntax
 */

class NullableFixer {
  constructor(options = {}) {
    this.dryRun = options.dryRun || false;
    this.backup = options.backup || false;
    this.changes = [];
  }

  /**
   * Main entry point - fix nullable in a YAML file
   */
  fixFile(inputPath) {
    console.log(`Reading file: ${inputPath}`);
    
    // Read the YAML file
    const content = fs.readFileSync(inputPath, 'utf8');
    
    // Parse YAML while preserving structure
    console.log('Parsing YAML...');
    const doc = yaml.parseDocument(content, {
      keepSourceTokens: true,
      keepCstNodes: true
    });
    
    // Traverse and fix nullable properties
    console.log('Fixing nullable properties...');
    this.traverseAndFix(doc.contents, []);
    
    // Convert back to YAML
    const output = doc.toString();
    
    // Report changes
    console.log(`\nFound and fixed ${this.changes.length} nullable properties`);
    
    if (this.dryRun) {
      console.log('\n=== DRY RUN - No changes written ===');
      this.printChangeSummary();
      return;
    }
    
    // Create backup if requested
    if (this.backup) {
      const backupPath = this.backup === true ? `${inputPath}.bak` : this.backup;
      console.log(`Creating backup: ${backupPath}`);
      fs.copyFileSync(inputPath, backupPath);
    }
    
    // Write the fixed file
    console.log(`Writing fixed file: ${inputPath}`);
    fs.writeFileSync(inputPath, output, 'utf8');
    
    console.log('\n✓ Successfully fixed nullable properties!');
    this.printChangeSummary();
  }

  /**
   * Recursively traverse YAML structure and fix nullable properties
   */
  traverseAndFix(node, path = []) {
    if (!node || typeof node !== 'object') {
      return;
    }

    // Handle Map (object) nodes
    if (node instanceof yaml.YAMLMap) {
      const items = node.items;
      
      for (let i = 0; i < items.length; i++) {
        const pair = items[i];
        const key = pair.key?.value;
        const value = pair.value;
        
        if (key) {
          const currentPath = [...path, key];
          
          // Check if this is a property with nullable: true
          if (value instanceof yaml.YAMLMap) {
            const hasNullable = this.hasProperty(value, 'nullable', true);
            
            if (hasNullable) {
              this.fixNullableProperty(value, currentPath);
            }
          }
          
          // Continue traversing
          this.traverseAndFix(value, currentPath);
        }
      }
    }
    // Handle Seq (array) nodes
    else if (node instanceof yaml.YAMLSeq) {
      node.items.forEach((item, index) => {
        this.traverseAndFix(item, [...path, `[${index}]`]);
      });
    }
  }

  /**
   * Check if a YAMLMap has a specific property with a specific value
   */
  hasProperty(map, propName, expectedValue = undefined) {
    if (!(map instanceof yaml.YAMLMap)) return false;
    
    const pair = map.items.find(p => p.key?.value === propName);
    if (!pair) return false;
    
    if (expectedValue !== undefined) {
      return pair.value?.value === expectedValue;
    }
    return true;
  }

  /**
   * Get the value of a property from a YAMLMap
   */
  getProperty(map, propName) {
    if (!(map instanceof yaml.YAMLMap)) return undefined;
    
    const pair = map.items.find(p => p.key?.value === propName);
    return pair?.value;
  }

  /**
   * Remove a property from a YAMLMap
   */
  removeProperty(map, propName) {
    if (!(map instanceof yaml.YAMLMap)) return;
    
    const index = map.items.findIndex(p => p.key?.value === propName);
    if (index >= 0) {
      map.items.splice(index, 1);
    }
  }

  /**
   * Add or update a property in a YAMLMap
   */
  setProperty(map, propName, value) {
    if (!(map instanceof yaml.YAMLMap)) return;
    
    const pair = map.items.find(p => p.key?.value === propName);
    if (pair) {
      pair.value = value;
    } else {
      map.items.push(
        new yaml.Pair(propName, value)
      );
    }
  }

  /**
   * Fix a property that has nullable: true
   */
  fixNullableProperty(propMap, path) {
    const pathStr = path.join(' > ');
    
    // Get existing properties
    const typeValue = this.getProperty(propMap, 'type');
    const allOfValue = this.getProperty(propMap, 'allOf');
    const oneOfValue = this.getProperty(propMap, 'oneOf');
    const anyOfValue = this.getProperty(propMap, 'anyOf');
    const enumValue = this.getProperty(propMap, 'enum');
    const refValue = this.getProperty(propMap, '$ref');
    
    let transformationType = 'unknown';

    // Rule 2: Has allOf - convert to anyOf with null
    if (allOfValue) {
      transformationType = 'allOf->anyOf';
      
      // Convert allOf to anyOf
      this.removeProperty(propMap, 'allOf');
      
      // Create new anyOf with null
      const anyOfSeq = new yaml.YAMLSeq();
      
      // Add all items from allOf
      if (allOfValue instanceof yaml.YAMLSeq) {
        allOfValue.items.forEach(item => {
          anyOfSeq.items.push(item);
        });
      }
      
      // Add null type
      const nullMap = new yaml.YAMLMap();
      nullMap.items.push(new yaml.Pair('type', 'null'));
      anyOfSeq.items.push(nullMap);
      
      this.setProperty(propMap, 'anyOf', anyOfSeq);
    }
    // Rule 2 variant: Has oneOf - add null to it
    else if (oneOfValue) {
      transformationType = 'oneOf+null';
      
      if (oneOfValue instanceof yaml.YAMLSeq) {
        // Add null type to existing oneOf
        const nullMap = new yaml.YAMLMap();
        nullMap.items.push(new yaml.Pair('type', 'null'));
        oneOfValue.items.push(nullMap);
      }
    }
    // Rule 2 variant: Has anyOf - add null to it
    else if (anyOfValue) {
      transformationType = 'anyOf+null';
      
      if (anyOfValue instanceof yaml.YAMLSeq) {
        // Add null type to existing anyOf
        const nullMap = new yaml.YAMLMap();
        nullMap.items.push(new yaml.Pair('type', 'null'));
        anyOfValue.items.push(nullMap);
      }
    }
    // Rule 5: Has enum - wrap in oneOf
    else if (enumValue) {
      transformationType = 'enum->oneOf';
      
      // Get the type if it exists
      const currentType = typeValue?.value || 'string';
      
      // Remove type and enum
      this.removeProperty(propMap, 'type');
      const enumToMove = this.getProperty(propMap, 'enum');
      this.removeProperty(propMap, 'enum');
      
      // Create oneOf with enum variant and null variant
      const oneOfSeq = new yaml.YAMLSeq();
      
      // Add enum variant
      const enumMap = new yaml.YAMLMap();
      enumMap.items.push(new yaml.Pair('type', currentType));
      enumMap.items.push(new yaml.Pair('enum', enumToMove));
      oneOfSeq.items.push(enumMap);
      
      // Add null variant
      const nullMap = new yaml.YAMLMap();
      nullMap.items.push(new yaml.Pair('type', 'null'));
      oneOfSeq.items.push(nullMap);
      
      this.setProperty(propMap, 'oneOf', oneOfSeq);
    }
    // Rule 1, 3, 4: Has simple type - convert to array
    else if (typeValue) {
      const currentType = typeValue.value;
      
      if (Array.isArray(currentType)) {
        // Edge case: already an array, add null if not present
        transformationType = 'type[]+null';
        if (!currentType.includes('null')) {
          currentType.push('null');
          this.setProperty(propMap, 'type', currentType);
        }
      } else {
        // Convert to array with null
        transformationType = 'type->type[]';
        const typeArray = new yaml.YAMLSeq();
        typeArray.items.push(new yaml.Scalar(currentType));
        typeArray.items.push(new yaml.Scalar('null'));
        this.setProperty(propMap, 'type', typeArray);
      }
    }
    // Edge case: Has only $ref - convert to anyOf
    else if (refValue) {
      transformationType = '$ref->anyOf';
      
      // Remove $ref
      const ref = this.getProperty(propMap, '$ref');
      this.removeProperty(propMap, '$ref');
      
      // Create anyOf
      const anyOfSeq = new yaml.YAMLSeq();
      
      // Add $ref variant
      const refMap = new yaml.YAMLMap();
      refMap.items.push(new yaml.Pair('$ref', ref));
      anyOfSeq.items.push(refMap);
      
      // Add null variant
      const nullMap = new yaml.YAMLMap();
      nullMap.items.push(new yaml.Pair('type', 'null'));
      anyOfSeq.items.push(nullMap);
      
      this.setProperty(propMap, 'anyOf', anyOfSeq);
    }
    
    // Remove nullable property
    this.removeProperty(propMap, 'nullable');
    
    // Record the change
    this.changes.push({
      path: pathStr,
      type: transformationType
    });
    
    if (this.dryRun) {
      console.log(`  [DRY RUN] ${pathStr} (${transformationType})`);
    }
  }

  /**
   * Print a summary of changes
   */
  printChangeSummary() {
    if (this.changes.length === 0) {
      console.log('No nullable properties found.');
      return;
    }
    
    // Group by transformation type
    const byType = {};
    this.changes.forEach(change => {
      if (!byType[change.type]) {
        byType[change.type] = [];
      }
      byType[change.type].push(change.path);
    });
    
    console.log('\nTransformation Summary:');
    Object.entries(byType).forEach(([type, paths]) => {
      console.log(`\n  ${type}: ${paths.length} occurrences`);
      if (this.dryRun && paths.length <= 10) {
        paths.forEach(p => console.log(`    - ${p}`));
      }
    });
  }
}

// CLI Interface
function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    console.log(`
OpenAPI Nullable Fixer
Converts OpenAPI 3.0.x nullable: true to OpenAPI 3.1.0 compatible syntax

Usage:
  node fix-nullable.js <input-file> [options]

Options:
  --dry-run         Preview changes without writing to file
  --backup [path]   Create backup before modifying (default: <input>.bak)
  --help, -h        Show this help message

Examples:
  node fix-nullable.js openapi.yaml
  node fix-nullable.js openapi.yaml --backup openapi.yaml.bak
  node fix-nullable.js openapi.yaml --dry-run
`);
    process.exit(0);
  }
  
  const inputFile = args[0];
  const options = {
    dryRun: args.includes('--dry-run'),
    backup: false
  };
  
  // Check for backup option
  const backupIndex = args.indexOf('--backup');
  if (backupIndex >= 0) {
    options.backup = args[backupIndex + 1] || true;
  }
  
  // Validate input file
  if (!fs.existsSync(inputFile)) {
    console.error(`Error: File not found: ${inputFile}`);
    process.exit(1);
  }
  
  try {
    const fixer = new NullableFixer(options);
    fixer.fixFile(inputFile);
  } catch (error) {
    console.error('Error:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = NullableFixer;