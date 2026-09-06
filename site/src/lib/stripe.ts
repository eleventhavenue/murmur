import Stripe from "stripe";
import { stripeSecretKey } from "./config";

export function createStripe(): Stripe {
  if (!stripeSecretKey) {
    throw new Error("Stripe requires STRIPE_SECRET_KEY");
  }
  return new Stripe(stripeSecretKey);
}
