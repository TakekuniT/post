import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import Stripe from "https://esm.sh/stripe?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-11-20",
});

serve(async (req) => {
  // 1. CORS Headers for iOS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const { userId, userEmail, priceId } = await req.json();

    // 2. Create the Session
    let tier = "free";
    if (priceId === "price_1Smep4AcB7EeiXzBHav3u4rz") tier = "pro";
    if (priceId === "price_1SmhKfAcB7EeiXzBNzMeQjhh") tier = "elite";

    const session = await stripe.checkout.sessions.create({
      customer_email: userEmail,
      line_items: [{ price: priceId, quantity: 1 }],
      mode: "subscription",
      metadata: {
        supabase_user_id: userId, // Keep this so the webhook knows who paid
        plan_tier: tier,
      },
      success_url: "unipost://success",
      cancel_url: "unipost://cancel",
    });

    // 3. Just return the URL. No DB update needed here because the row exists!
    return new Response(JSON.stringify({ url: session.url }), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      status: 200,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Access-Control-Allow-Origin": "*" },
      status: 400,
    });
  }
});
