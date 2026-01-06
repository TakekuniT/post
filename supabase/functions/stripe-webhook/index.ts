import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import Stripe from "https://esm.sh/stripe@14?target=denonext";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-11-20",
});
const cryptoProvider = Stripe.createSubtleCryptoProvider();

Deno.serve(async (req) => {
  const signature = req.headers.get("Stripe-Signature");
  const body = await req.text();

  let event;
  try {
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature!,
      Deno.env.get("STRIPE_WEBHOOK_SIGNING_SECRET")!,
      undefined,
      cryptoProvider
    );
  } catch (err) {
    return new Response(err.message, { status: 400 });
  }

  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // 1. HANDLE INITIAL PURCHASE
  if (event.type === "checkout.session.completed") {
    const session = event.data.object;
    const userId = session.metadata.supabase_user_id;

    // FIX: Read from metadata because line_items is usually empty in webhooks
    const tier = session.metadata.plan_tier;

    const { error } = await supabaseAdmin.from("subscriptions").upsert(
      {
        user_id: userId,
        stripe_customer_id: session.customer,
        stripe_subscription_id: session.subscription,
        tier: tier,
        status: "active",
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id" }
    );
  }

  /// 2. UPDATED LOGIC FOR TIER CHANGES
  if (event.type === "customer.subscription.updated") {
    const subscription = event.data.object;
    const priceId = subscription.items.data[0].price.id; // Get the CURRENT price
    const tier = session.metadata.plan_tier;

    const { error } = await supabaseAdmin
      .from("subscriptions")
      .update({
        tier: tier, // This ensures the tier updates if they upgrade/downgrade
        status: subscription.status,
        current_period_end: new Date(
          subscription.current_period_end * 1000
        ).toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("stripe_subscription_id", subscription.id);
  }

  // 3. HANDLE CANCELLATIONS (THE KILL SWITCH)
  if (event.type === "customer.subscription.deleted") {
    const subscription = event.data.object;
    const stripeCustomerId = subscription.customer;

    // We find the user by their Stripe Customer ID and reset them
    const { error } = await supabaseAdmin
      .from("subscriptions")
      .update({
        tier: "free",
        status: "canceled",
        stripe_subscription_id: null, // Clear the sub ID since it's dead
        updated_at: new Date().toISOString(),
      })
      .eq("stripe_customer_id", stripeCustomerId);

    if (error) {
      console.error(
        "CRITICAL ERROR: Could not downgrade user after cancellation:",
        error
      );
      // You might want to send yourself an alert here
    } else {
      console.log(
        `User with Customer ID ${stripeCustomerId} has been moved to Free Tier.`
      );
    }
  }

  // 4. HANDLE RECURRING PAYMENTS (MONTH 2, 3, etc.)
  if (event.type === "invoice.paid") {
    const invoice = event.data.object;

    // FIX: Use the period_end directly from the invoice line items
    const periodEnd = invoice.lines.data[0].period.end;

    await supabaseAdmin
      .from("subscriptions")
      .update({
        status: "active",
        current_period_end: new Date(periodEnd * 1000).toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("stripe_subscription_id", invoice.subscription);
  }

  // 5. HANDLE FAILED PAYMENTS
  if (event.type === "invoice.payment_failed") {
    const invoice = event.data.object;
    const subscriptionId = invoice.subscription;

    // Update DB to 'past_due'. This is your signal to block the app's premium features.
    await supabaseAdmin
      .from("subscriptions")
      .update({
        status: "past_due",
        updated_at: new Date().toISOString(),
      })
      .eq("stripe_subscription_id", subscriptionId);

    console.log(
      `Subscription ${subscriptionId} is now past_due. Access should be restricted.`
    );
  }

  return new Response(JSON.stringify({ received: true }), { status: 200 });
});
