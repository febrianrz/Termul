import { Router } from "express";

import { config } from "../config";

const router = Router();

interface AlterTokenResponse {
  token_type: string;
  expires_in: number;
  access_token: string;
  refresh_token: string;
}

class AlterTokenError extends Error {
  constructor(
    public status: number,
    public details: string,
  ) {
    super(`Alter Indonesia token request failed (${status})`);
  }
}

async function requestAlterToken(
  body: Record<string, string>,
): Promise<AlterTokenResponse> {
  const response = await fetch(`${config.alterBaseUrl}/oauth/token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Accept: "application/json",
    },
    body: new URLSearchParams(body),
  });

  if (!response.ok) {
    throw new AlterTokenError(response.status, await response.text());
  }

  return (await response.json()) as AlterTokenResponse;
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
    const token = await requestAlterToken({
      grant_type: "authorization_code",
      client_id: config.alterClientId,
      client_secret: config.alterClientSecret,
      redirect_uri: config.alterRedirectUri,
      code,
    });
    res.json(token);
  } catch (err) {
    if (err instanceof AlterTokenError) {
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
    const token = await requestAlterToken({
      grant_type: "refresh_token",
      client_id: config.alterClientId,
      client_secret: config.alterClientSecret,
      refresh_token: refreshToken,
    });
    res.json(token);
  } catch (err) {
    if (err instanceof AlterTokenError) {
      res
        .status(err.status)
        .json({ error: "Token refresh failed", details: err.details });
      return;
    }
    throw err;
  }
});

export default router;
