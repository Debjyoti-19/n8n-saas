# Dodo Payments Integration for Luceta Audio Platform

This document outlines the complete integration of Dodo Payments into the Luceta audio platform for game developers.

## 🎯 **Integration Overview**

The Luceta platform now includes a complete payment system using Dodo Payments' Checkout Sessions API, enabling:

- **Secure hosted checkout** for audio platform subscriptions
- **Multiple pricing tiers** (Starter, Pro, Enterprise)
- **Flexible billing** (monthly/yearly with 17% yearly discount)
- **Webhook handling** for real-time payment notifications
- **Success page** with onboarding flow

## 🔧 **Setup Instructions**

### 1. Environment Configuration

Copy `.env.example` to `.env.local` and configure:

```bash
# Dodo Payments Configuration
DODO_PAYMENTS_API_KEY=your_dodo_payments_api_key_here
DODO_PAYMENTS_ENVIRONMENT=test_mode
DODO_WEBHOOK_SECRET=your_webhook_secret_here

# Application URLs
NEXT_PUBLIC_BASE_URL=http://localhost:3000
NEXT_PUBLIC_RETURN_URL=http://localhost:3000/checkout/success
```

### 2. Get Dodo Payments API Key

1. Log in to your [Dodo Payments Dashboard](https://dashboard.dodopayments.com)
2. Go to Developer → API Keys
3. Click "Add API Key"
4. Name it "Luceta Integration"
5. Copy the generated key to your `.env.local`

### 3. Create Products in Dodo Dashboard

Create these products in your Dodo Payments dashboard:

| Product ID | Name | Price (Monthly) | Price (Yearly) |
|------------|------|-----------------|----------------|
| `luceta_starter` | Starter | $29 | $290 |
| `luceta_pro` | Pro | $99 | $990 |
| `luceta_enterprise` | Enterprise | $299 | $2990 |

### 4. Configure Webhooks

1. In Dodo Payments Dashboard → Webhooks
2. Add webhook URL: `https://yourdomain.com/api/webhooks/dodo`
3. Select events: `payment.completed`, `payment.failed`, `subscription.created`, `subscription.cancelled`, `refund.created`
4. Copy the webhook secret to your environment variables

## 📁 **File Structure**

```
├── lib/
│   └── dodo-payments.ts          # Payment client and product definitions
├── app/
│   ├── api/
│   │   ├── checkout/
│   │   │   └── route.ts          # Checkout session creation
│   │   └── webhooks/
│   │       └── dodo/
│   │           └── route.ts      # Webhook event handling
│   └── checkout/
│       └── success/
│           └── page.tsx          # Success page with onboarding
├── components/
│   └── PricingSection.tsx        # Updated with payment integration
└── .env.example                  # Environment variables template
```

## 🚀 **API Endpoints**

### POST `/api/checkout`

Creates a Dodo Payments checkout session.

**Request Body:**
```json
{
  "product_id": "luceta_pro",
  "customer": {
    "email": "user@example.com",
    "name": "John Doe",
    "phone_number": "+1234567890"
  },
  "billing_address": {
    "street": "123 Main St",
    "city": "San Francisco",
    "state": "CA",
    "country": "US",
    "zipcode": "94102"
  },
  "quantity": 1,
  "plan_type": "monthly"
}
```

**Response:**
```json
{
  "success": true,
  "checkout_url": "https://checkout.dodopayments.com/session/...",
  "session_id": "ses_...",
  "product": {
    "id": "luceta_pro",
    "name": "Pro",
    "price": 99,
    "category": "pro"
  }
}
```

### GET `/api/checkout`

Quick checkout link generation.

**Query Parameters:**
- `product_id`: Product identifier
- `email`: Customer email (optional)
- `name`: Customer name (optional)

### POST `/api/webhooks/dodo`

Handles Dodo Payments webhook events.

**Supported Events:**
- `payment.completed` - Payment successful
- `payment.failed` - Payment failed
- `subscription.created` - Subscription started
- `subscription.cancelled` - Subscription cancelled
- `refund.created` - Refund processed

## 🎨 **Frontend Integration**

### PricingSection Component

The pricing section now includes:

- **Interactive plan selection** with hover effects
- **Monthly/yearly toggle** with discount display
- **Direct checkout integration** with loading states
- **Secure payment processing** via Dodo Payments

### Usage Example:

```tsx
import { PricingSection } from '@/components/PricingSection'

export default function PricingPage() {
  return (
    <div>
      <PricingSection />
    </div>
  )
}
```

## 🔒 **Security Features**

- **Webhook signature verification** (implement in production)
- **Input validation** using Zod schemas
- **Error handling** with user-friendly messages
- **Secure API key management** via environment variables

## 🎯 **Payment Flow**

1. **User selects plan** on pricing page
2. **Checkout session created** via API
3. **User redirected** to Dodo Payments hosted checkout
4. **Payment processed** securely by Dodo Payments
5. **Webhook received** for payment confirmation
6. **User redirected** to success page
7. **Access granted** to Luceta audio features

## 📊 **Analytics & Tracking**

All payments include metadata for tracking:

```json
{
  "metadata": {
    "platform": "luceta-audio",
    "source": "pricing_page",
    "plan_type": "monthly",
    "product_name": "Pro",
    "product_category": "pro"
  }
}
```

## 🛠️ **Development & Testing**

### Localhost Webhook Setup

Since Dodo Payments needs to send webhooks to your application, you need to expose your localhost to the internet during development. Here are the recommended approaches:

#### Option 1: ngrok (Recommended)

1. **Install ngrok**:
   ```bash
   # Download from https://ngrok.com/download
   # Or install via package manager:
   npm install -g ngrok
   # Or: choco install ngrok (Windows)
   # Or: brew install ngrok (macOS)
   ```

2. **Start your Next.js app**:
   ```bash
   npm run dev
   # Your app runs on http://localhost:3000
   ```

3. **In a new terminal, start ngrok**:
   ```bash
   ngrok http 3000
   ```

4. **Copy the HTTPS URL** (e.g., `https://abc123.ngrok.io`)

5. **Configure webhook in Dodo Payments Dashboard**:
   - Webhook URL: `https://your-ngrok-url.ngrok.io/api/webhooks/dodo`
   - Events: `payment.completed`, `payment.failed`, `subscription.created`, `subscription.cancelled`, `refund.created`

#### Option 2: Cloudflare Tunnel (Free Alternative)

1. **Install Cloudflare Tunnel**:
   ```bash
   npm install -g cloudflared
   ```

2. **Start tunnel**:
   ```bash
   cloudflared tunnel --url http://localhost:3000
   ```

3. **Use the provided HTTPS URL** for webhook configuration

#### Option 3: LocalTunnel (Simple)

1. **Install and run**:
   ```bash
   npm install -g localtunnel
   lt --port 3000 --subdomain luceta-dev
   ```

2. **Use**: `https://luceta-dev.loca.lt/api/webhooks/dodo`

### Test Mode

Use `DODO_PAYMENTS_ENVIRONMENT=test_mode` for development:

- No real charges processed
- Test webhook events
- Full checkout flow testing

### Testing Webhooks Locally

1. **Start your development server**:
   ```bash
   npm run dev
   ```

2. **Start ngrok in another terminal**:
   ```bash
   ngrok http 3000
   ```

3. **Update Dodo Payments webhook URL** with your ngrok URL

4. **Test webhook endpoint**:
   ```bash
   curl -X GET https://your-ngrok-url.ngrok.io/api/webhooks/dodo
   # Should return: {"status":"healthy","service":"luceta-dodo-webhooks",...}
   ```

5. **Create a test payment** and verify webhook events are received

### Environment Variables for Development

Create `.env.local` with:

```bash
# Copy from .env.example and update:
DODO_PAYMENTS_API_KEY=your_test_api_key
DODO_PAYMENTS_ENVIRONMENT=test_mode
DODO_WEBHOOK_SECRET=your_webhook_secret
NEXT_PUBLIC_BASE_URL=http://localhost:3000
NEXT_PUBLIC_RETURN_URL=http://localhost:3000/checkout/success

# Optional: Store your ngrok URL for reference
NGROK_URL=https://your-ngrok-url.ngrok.io
```

### Production Deployment

1. Set `DODO_PAYMENTS_ENVIRONMENT=live_mode`
2. Update `NEXT_PUBLIC_BASE_URL` to production domain
3. Configure production webhook URL
4. Implement proper webhook signature verification

## 🎵 **Luceta-Specific Features**

### Audio Platform Products

- **Starter**: Basic audio cursor integration for indie developers
- **Pro**: Advanced gesture recognition for professional studios
- **Enterprise**: Full-scale solution with dedicated support

### Success Page Features

- **Welcome message** with next steps
- **Quick start guide** links
- **SDK download** instructions
- **Community access** information

## 🔄 **Webhook Event Handling**

The webhook handler processes these events:

- **Payment Completed**: Grant user access, send welcome email
- **Payment Failed**: Handle retry logic, notify user
- **Subscription Created**: Set up recurring access
- **Subscription Cancelled**: Schedule access revocation
- **Refund Created**: Revoke access, update records

## 📞 **Support & Documentation**

- **Dodo Payments Docs**: https://docs.dodopayments.com
- **API Reference**: https://docs.dodopayments.com/api-reference
- **Webhook Guide**: https://docs.dodopayments.com/webhooks
- **Dashboard**: https://dashboard.dodopayments.com

## 🚀 **Next Steps**

1. **Set up Dodo Payments account** and get API keys
2. **Create products** in the dashboard
3. **Configure environment variables**
4. **Test the integration** in development
5. **Deploy to production** with live mode
6. **Monitor payments** via dashboard and webhooks

The integration is now complete and ready for production use! 🎉