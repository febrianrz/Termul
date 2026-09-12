import { Router } from "express";

import { config } from "../config";

const router = Router();

interface SsoTokenResponse {
  token_type: string;
  expires_in: number;
  access_token: string;
  refresh_token: string;
}

class SsoTokenError extends Error {
  constructor(
    public status: number,
    public details: string,
  ) {
    super(`SSO token request failed (${status})`);
  }
}

async function requestSsoToken(
  body: Record<string, string>,
): Promise<SsoTokenResponse> {
  const response = await fetch(`${config.ssoBaseUrl}/oauth/token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Accept: "application/json",
    },
    body: new URLSearchParams(body),
  });

  if (!response.ok) {
    throw new SsoTokenError(response.status, await response.text());
  }

  return (await response.json()) as SsoTokenResponse;
}

/**
 * Exchanges an authorization `code` (obtained by the mobile app from
 * /oauth/authorize) for tokens. Kept server-side because it requires
 * client_secret, which must never ship inside the app.
 */
router.post("/exchange", async (req, res) => {
  const { code } = req.body ?? {};
  if (typeof code !== "string" || code.length === 0) {
    res.status(400).json({ error: "Missing 'code'" });
    return;
  }

  try {
    const token = await requestSsoToken({
      grant_type: "authorization_code",
      client_id: config.ssoClientId,
      client_secret: config.ssoClientSecret,
      redirect_uri: config.ssoRedirectUri,
      code,
    });
    res.json(token);
  } catch (err) {
    if (err instanceof SsoTokenError) {
      res
        .status(err.status)
        .json({ error: "Token exchange failed", details: err.details });
      return;
    }
    throw err;
  }
});

router.post("/refresh", async (req, res) => {
  const { refresh_token: refreshToken } = req.body ?? {};
  if (typeof refreshToken !== "string" || refreshToken.length === 0) {
    res.status(400).json({ error: "Missing 'refresh_token'" });
    return;
  }

  try {
    const token = await requestSsoToken({
      grant_type: "refresh_token",
      client_id: config.ssoClientId,
      client_secret: config.ssoClientSecret,
      refresh_token: refreshToken,
    });
    res.json(token);
  } catch (err) {
    if (err instanceof SsoTokenError) {
      res
        .status(err.status)
        .json({ error: "Token refresh failed", details: err.details });
      return;
    }
    throw err;
  }
});

export default router;
