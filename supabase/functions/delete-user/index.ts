import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
// This specific URL is much more stable for Deno
import Stripe from "https://cdn.jsdelivr.net/npm/stripe@13.10.0/+esm";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS")
    return new Response("ok", { headers: corsHeaders });

  const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
    httpClient: Stripe.createFetchHttpClient(),
  });

  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  try {
    const authHeader = req.headers.get("Authorization");
    const token = authHeader?.replace("Bearer ", "");
    const {
      data: { user },
      error: authError,
    } = await supabaseAdmin.auth.getUser(token);

    if (authError || !user) throw new Error("Auth verification failed");

    // --- STRIPE CLEANUP START ---
    // 1. Get the stripe_customer_id from your subscriptions table
    const { data: subData } = await supabaseAdmin
      .from("subscriptions")
      .select("stripe_customer_id")
      .eq("user_id", user.id)
      .maybeSingle();

    if (subData?.stripe_customer_id) {
      console.log(
        `Canceling subscriptions for customer: ${subData.stripe_customer_id}`
      );

      // 2. List all active or trialing subscriptions
      const subscriptions = await stripe.subscriptions.list({
        customer: subData.stripe_customer_id,
        status: "active",
      });

      // 3. Cancel them immediately so they aren't charged again
      for (const sub of subscriptions.data) {
        await stripe.subscriptions.cancel(sub.id);
        console.log(`Canceled subscription: ${sub.id}`);
      }
    }
    // --- STRIPE CLEANUP END ---

    // 4. Delete the User from Auth (Cascades to profile/posts)
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(
      user.id
    );
    if (deleteError) throw deleteError;

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error("Deletion Error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
