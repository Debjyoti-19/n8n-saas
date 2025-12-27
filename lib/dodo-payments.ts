// Dodo Payments integration for Luceta Audio Platform
export interface DodoPaymentsConfig {
  bearerToken: string;
  environment: 'test_mode' | 'live_mode';
  returnUrl: string;
}

export interface AudioProduct {
  id: string;
  name: string;
  description: string;
  price: number;
  category: 'starter' | 'pro' | 'enterprise';
  features: string[];
}

export interface CheckoutSessionData {
  product_cart: Array<{
    product_id: string;
    quantity: number;
  }>;
  customer: {
    email: string;
    name: string;
    phone_number?: string;
  };
  billing_address?: {
    street: string;
    city: string;
    state: string;
    country: string;
    zipcode: string;
  };
  return_url: string;
  metadata?: {
    platform: string;
    source: string;
    plan_type?: string;
  };
}

export interface PaymentResponse {
  checkout_url: string;
  session_id: string;
  payment_id?: string;
}

export class DodoPaymentsClient {
  private config: DodoPaymentsConfig;
  private baseUrl: string;

  constructor(config: DodoPaymentsConfig) {
    this.config = config;
    this.baseUrl = config.environment === 'test_mode' 
      ? 'https://test.dodopayments.com' 
      : 'https://api.dodopayments.com';
  }

  async createCheckoutSession(data: CheckoutSessionData): Promise<PaymentResponse> {
    try {
      const response = await fetch(`${this.baseUrl}/checkouts`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.config.bearerToken}`,
        },
        body: JSON.stringify({
          ...data,
          metadata: {
            platform: 'luceta-audio',
            source: 'web_app',
            ...data.metadata,
          },
        }),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => null);
        throw new Error(`Payment session creation failed: ${response.status} ${errorData?.message || ''}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Dodo Payments checkout session error:', error);
      throw error;
    }
  }

  async createPaymentLink(data: Omit<CheckoutSessionData, 'product_cart'> & {
    product_id: string;
    quantity?: number;
  }): Promise<PaymentResponse> {
    try {
      const response = await fetch(`${this.baseUrl}/payments`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.config.bearerToken}`,
        },
        body: JSON.stringify({
          payment_link: true,
          billing: data.billing_address ? {
            city: data.billing_address.city,
            country: data.billing_address.country,
            state: data.billing_address.state,
            street: data.billing_address.street,
            zipcode: parseInt(data.billing_address.zipcode),
          } : undefined,
          customer: data.customer,
          product_cart: [{
            product_id: data.product_id,
            quantity: data.quantity || 1,
          }],
          return_url: data.return_url,
          metadata: {
            platform: 'luceta-audio',
            source: 'web_app',
            ...data.metadata,
          },
        }),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => null);
        throw new Error(`Payment link creation failed: ${response.status} ${errorData?.message || ''}`);
      }

      const result = await response.json();
      return {
        checkout_url: result.payment_link,
        session_id: result.payment_id,
        payment_id: result.payment_id,
      };
    } catch (error) {
      console.error('Dodo Payments payment link error:', error);
      throw error;
    }
  }
}

// Luceta Audio Platform Products
export const LUCETA_PRODUCTS: AudioProduct[] = [
  {
    id: 'pdt_0NUtoiCotZwkQTWTxwEge', // Actual product ID from Dodo Payments
    name: 'Starter',
    description: 'Perfect for indie game developers getting started with audio',
    price: 29,
    category: 'starter',
    features: [
      'Audio cursor integration',
      'Up to 50 audio experiences/month',
      'Basic game engine support',
      'Community support',
      'One-click global deployment',
      'Game engine integration',
    ],
  },
  {
    id: 'pdt_0NUtoiR120tOcI7kvVYM3', // Actual product ID from Dodo Payments
    name: 'Pro',
    description: 'Advanced features for professional game studios',
    price: 99,
    category: 'pro',
    features: [
      'Advanced gesture recognition',
      'Up to 1,000 audio experiences/month',
      'Multi-platform deployment',
      'Priority support',
      'One-click global deployment',
      'Game engine integration',
    ],
  },
  {
    id: 'pdt_0NUtoieCPfDZnA2fSkpKE', // Actual product ID from Dodo Payments
    name: 'Enterprise',
    description: 'Full-scale solution for large game development teams',
    price: 299,
    category: 'enterprise',
    features: [
      'Custom audio templates',
      'Unlimited audio experiences',
      'Dedicated audio engineering support',
      '24/7 technical assistance',
      'One-click global deployment',
      'Game engine integration',
    ],
  },
];

export function getProductById(id: string): AudioProduct | undefined {
  return LUCETA_PRODUCTS.find(product => product.id === id);
}

export function getProductsByCategory(category: string): AudioProduct[] {
  return LUCETA_PRODUCTS.filter(product => product.category === category);
}