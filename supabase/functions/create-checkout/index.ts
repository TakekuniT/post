import { serve } from "https://deno.land/std@0.190.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";
// We use a slightly different Stripe import that is strictly for Deno
import Stripe from "https://esm.sh/stripe@14.23.0?target=deno&no-check";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") || "", {
  apiVersion: "2023-10-16",
  // This is the CRITICAL line that stops the Microtasks error
  httpClient: Stripe.createFetchHttpClient(),
});

serve(async (req) => {
  const headers = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("No authorization header");

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      //Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
      Deno.env.get("SUPABASE_ANON_KEY") ?? ""
    );

    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: authError,
    } = await supabaseClient.auth.getUser(token);

    if (authError || !user) throw new Error("Invalid token");

    const { tier } = await req.json();

    // Downgrade protection
    const { data: profile, error: profileError } = await supabaseClient
      .from("profiles")
      .select("tier")
      .eq("id", user.id)
      .single();

    if (profileError) console.error("Profile Fetch Error:", profileError);

    const tierWeights: Record<string, number> = {
      free: 0,
      pro: 1,
      elite: 2,
      loading: 0,
    };
    const currentWeight = tierWeights[(profile?.tier || "free").toLowerCase()];
    const targetWeight = tierWeights[tier.toLowerCase()];

    // Block if target is lower or equal to current (except free)
    if (targetWeight <= currentWeight && currentWeight !== 0) {
      throw new Error(
        "You already have this plan or a higher one. Please manage downgrades via Apple Settings."
      );
    }

    let priceId = "";
    if (tier === "pro") priceId = "price_1Smep4AcB7EeiXzBHav3u4rz";
    if (tier === "elite") priceId = "price_1SmhKfAcB7EeiXzBNzMeQjhh";

    if (!priceId) throw new Error(`Invalid tier: ${tier}`);
    console.log("Creating Stripe Session with Metadata:", {
      supabase_user_id: user.id,
      plan_tier: tier,
    });
    const session = await (stripe as any).checkout.sessions.create({
      customer_email: user.email,
      line_items: [{ price: priceId, quantity: 1 }],
      mode: "subscription",
      metadata: {
        supabase_user_id: user.id,
        plan_tier: tier,
      },
      success_url: "xpost://success",
      cancel_url: "xpost://cancel",
    });

    return new Response(JSON.stringify({ url: session.url }), {
      headers: { ...headers, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error("LOG ERROR:", (error as any).message);
    return new Response(JSON.stringify({ error: (error as any).message }), {
      headers: { ...headers, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
