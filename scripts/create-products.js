#!/usr/bin/env node

/**
 * Create Luceta Audio Products in Dodo Payments
 * This script creates the required products for the Luceta platform
 */

import { readFileSync } from 'fs';
import { join } from 'path';

// Load environment variables from .env file
function loadEnvFile() {
  try {
    const envPath = join(process.cwd(), '.env');
    const envContent = readFileSync(envPath, 'utf8');
    
    envContent.split('\n').forEach(line => {
      const trimmedLine = line.trim();
      if (trimmedLine && !trimmedLine.startsWith('#')) {
        const [key, ...valueParts] = trimmedLine.split('=');
        if (key && valueParts.length > 0) {
          const value = valueParts.join('=');
          process.env[key] = value;
        }
      }
    });
  } catch (error) {
    console.log('⚠️  Could not load .env file:', error.message);
  }
}

loadEnvFile();

console.log('Script starting...');

const DODO_API_KEY = process.env.DODO_PAYMENTS_API_KEY;
const DODO_ENVIRONMENT = process.env.DODO_PAYMENTS_ENVIRONMENT || 'test_mode';

const baseUrl = DODO_ENVIRONMENT === 'test_mode' 
  ? 'https://test.dodopayments.com' 
  : 'https://api.dodopayments.com';

// Luceta Audio Products
const products = [
  {
    id: 'luceta_starter',
    name: 'Starter',
    description: 'Perfect for indie game developers getting started with audio cursor technology. Build locally, sell globally with basic audio experiences.',
    price: {
      currency: 'USD',
      price: 2900, // $29.00 in cents
      type: 'one_time_price',
      discount: 0,
      pay_what_you_want: false,
      purchasing_power_parity: false,
      tax_inclusive: false
    },
    tax_category: 'digital_products',
    metadata: {
      category: 'starter',
      platform: 'luceta-audio',
      features: 'audio-cursor,basic-integration,community-support'
    }
  },
  {
    id: 'luceta_pro',
    name: 'Pro',
    description: 'Advanced features for professional game studios. Advanced gesture recognition and multi-platform deployment for audio engineering.',
    price: {
      currency: 'USD',
      price: 9900, // $99.00 in cents
      type: 'one_time_price',
      discount: 0,
      pay_what_you_want: false,
      purchasing_power_parity: false,
      tax_inclusive: false
    },
    tax_category: 'digital_products',
    metadata: {
      category: 'pro',
      platform: 'luceta-audio',
      features: 'advanced-gestures,multi-platform,priority-support'
    }
  },
  {
    id: 'luceta_enterprise',
    name: 'Enterprise',
    description: 'Full-scale solution for large game development teams. Custom audio templates with unlimited experiences and dedicated support.',
    price: {
      currency: 'USD',
      price: 29900, // $299.00 in cents
      type: 'one_time_price',
      discount: 0,
      pay_what_you_want: false,
      purchasing_power_parity: false,
      tax_inclusive: false
    },
    tax_category: 'digital_products',
    metadata: {
      category: 'enterprise',
      platform: 'luceta-audio',
      features: 'custom-templates,unlimited,dedicated-support'
    }
  }
];

async function createProduct(productData) {
  console.log(`\n🎵 Creating product: ${productData.name}...`);
  
  try {
    const response = await fetch(`${baseUrl}/products`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${DODO_API_KEY}`
      },
      body: JSON.stringify({
        name: productData.name,
        description: productData.description,
        price: productData.price,
        tax_category: productData.tax_category,
        metadata: productData.metadata
      })
    });
    
    const data = await response.json();
    
    if (response.ok) {
      console.log(`✅ Product created successfully`);
      console.log(`   Product ID: ${data.product_id || data.id}`);
      console.log(`   Name: ${data.name}`);
      console.log(`   Price: $${(data.price.price / 100).toFixed(2)}`);
      return { success: true, product: data };
    } else {
      console.log(`❌ Failed to create product`);
      console.log(`   Status: ${response.status}`);
      console.log(`   Error:`, data);
      return { success: false, error: data };
    }
  } catch (error) {
    console.log(`❌ Error creating product`);
    console.log(`   Error: ${error.message}`);
    return { success: false, error: error.message };
  }
}

async function listExistingProducts() {
  console.log('\n📋 Checking existing products...');
  
  try {
    const response = await fetch(`${baseUrl}/products`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${DODO_API_KEY}`
      }
    });
    
    const data = await response.json();
    
    if (response.ok) {
      console.log(`✅ Found ${data.data?.length || 0} existing products`);
      
      if (data.data && data.data.length > 0) {
        data.data.forEach(product => {
          const price = product.price?.price ? (product.price.price / 100).toFixed(2) : 'N/A';
          console.log(`   - ${product.name} (${product.product_id || product.id}) - $${price}`);
        });
      }
      
      return data.data || [];
    } else {
      console.log(`❌ Failed to list products`);
      console.log(`   Status: ${response.status}`);
      console.log(`   Error:`, data);
      return [];
    }
  } catch (error) {
    console.log(`❌ Error listing products`);
    console.log(`   Error: ${error.message}`);
    return [];
  }
}

async function createAllProducts() {
  console.log('🚀 Luceta Audio Platform - Product Creation');
  console.log('='.repeat(50));
  console.log(`Environment: ${DODO_ENVIRONMENT}`);
  console.log(`API Base URL: ${baseUrl}`);
  console.log(`API Key: ${DODO_API_KEY ? 'configured' : 'NOT SET'}`);
  
  if (!DODO_API_KEY) {
    console.log('❌ DODO_PAYMENTS_API_KEY not found in environment variables');
    console.log('Please make sure your .env file contains the API key');
    return false;
  }
  
  // List existing products first
  const existingProducts = await listExistingProducts();
  const existingIds = existingProducts.map(p => p.product_id || p.id);
  
  let created = 0;
  let skipped = 0;
  let failed = 0;
  
  for (const productData of products) {
    if (existingIds.includes(productData.id)) {
      console.log(`\n⏭️  Product ${productData.name} (${productData.id}) already exists, skipping...`);
      skipped++;
      continue;
    }
    
    const result = await createProduct(productData);
    if (result.success) {
      created++;
    } else {
      failed++;
    }
    
    // Small delay between requests
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  
  console.log('\n📊 Product Creation Results:');
  console.log(`   Created: ${created}`);
  console.log(`   Skipped: ${skipped}`);
  console.log(`   Failed: ${failed}`);
  
  if (created > 0) {
    console.log('\n🎉 Products created successfully!');
    console.log('You can now test the checkout integration.');
    console.log('\nNext steps:');
    console.log('1. Run: node scripts/test-integration.js');
    console.log('2. Set up ngrok for webhook testing');
    console.log('3. Test real payments in your dashboard');
  }
  
  return failed === 0;
}

// Run if called directly
console.log('Running main function...');
createAllProducts()
  .then(success => {
    process.exit(success ? 0 : 1);
  })
  .catch(error => {
    console.error('Product creation error:', error);
    process.exit(1);
  });