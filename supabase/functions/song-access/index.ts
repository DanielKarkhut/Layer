import { createClient } from "npm:@supabase/supabase-js@2";

const SIGNED_URL_TTL_SECONDS = 300;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type SongAccessRequest = {
  song_id?: string;
  lat?: number;
  lng?: number;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Use POST." }, 405);
  }

  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization) {
      return json({ error: "Sign in before listening to a song." }, 401);
    }

    const body = await req.json() as SongAccessRequest;
    if (!body.song_id || typeof body.lat !== "number" || typeof body.lng !== "number") {
      return json({ error: "song_id, lat, and lng are required." }, 400);
    }

    const supabaseURL = requiredEnv("SUPABASE_URL");
    const publishableKey = readSupabaseKey("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY");
    const secretKey = readSupabaseKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY");

    const userClient = createClient(supabaseURL, publishableKey, {
      global: {
        headers: {
          Authorization: authorization,
        },
      },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return json({ error: "Sign in before listening to a song." }, 401);
    }

    const adminClient = createClient(supabaseURL, secretKey);
    const { data: rows, error: songError } = await adminClient.rpc("get_song_access", {
      song_id: body.song_id,
      lat: body.lat,
      lng: body.lng,
    });

    if (songError) {
      console.error(songError);
      return json({ error: "Song access check failed." }, 500);
    }

    const song = Array.isArray(rows) ? rows[0] : undefined;
    if (!song) {
      return json({ error: "Move closer to this song before listening." }, 403);
    }

    const { data: signedURL, error: signedURLError } = await adminClient.storage
      .from("song")
      .createSignedUrl(song.storage_path, SIGNED_URL_TTL_SECONDS);

    if (signedURLError || !signedURL?.signedUrl) {
      console.error(signedURLError);
      return json({ error: "Could not create a playback URL." }, 500);
    }

    return json({
      signed_url: signedURL.signedUrl,
      expires_in: SIGNED_URL_TTL_SECONDS,
      name: song.name,
      uploaded_by: song.uploaded_by,
    });
  } catch (error) {
    console.error(error);
    return json({ error: "Song access failed." }, 500);
  }
});

function json(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, {
    status,
    headers: corsHeaders,
  });
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`${name} is not configured.`);
  }

  return value;
}

function readSupabaseKey(jsonEnvName: string, legacyEnvName: string): string {
  const rawJSON = Deno.env.get(jsonEnvName);
  if (rawJSON) {
    const parsed = JSON.parse(rawJSON) as Record<string, unknown>;
    const defaultKey = parsed.default;
    if (typeof defaultKey === "string") {
      return defaultKey;
    }

    const firstKey = Object.values(parsed).find((value) => typeof value === "string");
    if (typeof firstKey === "string") {
      return firstKey;
    }
  }

  return requiredEnv(legacyEnvName);
}
