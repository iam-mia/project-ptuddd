// Supabase Edge Function: generate-learning-content
// Calls Google Gemini 2.5 Flash API with Structured Outputs (JSON Schema)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { contentType, count = 10, difficulty = "medium", topic, documentContext } =
      await req.json();

    if (!documentContext || documentContext.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "Nội dung tài liệu không được để trống" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (count < 5 || count > 20) {
      return new Response(
        JSON.stringify({ error: "Số lượng câu hỏi/thẻ phải từ 5 đến 20 (BR-04)" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiApiKey) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY chưa được cấu hình trong Supabase Secrets" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        status: "ready",
        contentType,
        count,
        difficulty,
        topic,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
