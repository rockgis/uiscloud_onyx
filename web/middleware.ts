import { NextRequest, NextResponse } from "next/server";
import {
  SERVER_SIDE_ONLY__PAID_ENTERPRISE_FEATURES_ENABLED,
} from "./src/lib/constants";

// Cookie name for storing the user's locale preference
const NEXT_LOCALE_COOKIE = "NEXT_LOCALE";
const LOCALES = ["en", "ko"] as const;
const DEFAULT_LOCALE = "en";

// Authentication cookie names (matches backend constants)
const FASTAPI_USERS_AUTH_COOKIE_NAME = "fastapiusersauth";
const ANONYMOUS_USER_COOKIE_NAME = "onyx_anonymous_user";

// Protected route prefixes (require authentication)
const PROTECTED_ROUTES = ["/app", "/admin", "/assistants", "/connector"];

// Public route prefixes (no authentication required)
const PUBLIC_ROUTES = ["/auth", "/anonymous", "/_next", "/api"];

// Enterprise Edition specific routes (ONLY these get /ee rewriting)
const EE_ROUTES = [
  "/admin/groups",
  "/admin/performance/usage",
  "/admin/performance/query-history",
  "/admin/theme",
  "/admin/performance/custom-analytics",
  "/admin/standard-answer",
  "/assistants/stats",
];

export const config = {
  matcher: [
    // Auth-protected + i18n routes
    "/((?!_next|_vercel|.*\\..*).*)",
  ],
};

export default function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // ── 1. Auth Check (fast-fail for unauthenticated requests) ──────────────
  const isProtectedRoute = PROTECTED_ROUTES.some((r) => pathname.startsWith(r));
  const isPublicRoute = PUBLIC_ROUTES.some((r) => pathname.startsWith(r));

  if (isProtectedRoute && !isPublicRoute) {
    const authCookie = request.cookies.get(FASTAPI_USERS_AUTH_COOKIE_NAME);
    const anonymousCookie = request.cookies.get(ANONYMOUS_USER_COOKIE_NAME);

    if (!authCookie && !anonymousCookie) {
      const loginUrl = new URL("/auth/login", request.url);
      const fullPath = pathname + request.nextUrl.search + request.nextUrl.hash;
      loginUrl.searchParams.set("next", fullPath);
      return NextResponse.redirect(loginUrl);
    }
  }

  // ── 2. Enterprise Edition: Rewrite EE-specific routes ───────────────────
  if (SERVER_SIDE_ONLY__PAID_ENTERPRISE_FEATURES_ENABLED) {
    if (EE_ROUTES.some((r) => pathname.startsWith(r))) {
      const newUrl = new URL(`/ee${pathname}`, request.url);
      return NextResponse.rewrite(newUrl);
    }
  }

  // ── 3. Locale detection — set x-next-intl-locale header ─────────────────
  // next-intl "without i18n routing" mode: no URL rewrites, just header injection
  const localeCookie = request.cookies.get(NEXT_LOCALE_COOKIE)?.value;
  const locale: (typeof LOCALES)[number] = (
    LOCALES as readonly string[]
  ).includes(localeCookie ?? "")
    ? (localeCookie as (typeof LOCALES)[number])
    : DEFAULT_LOCALE;

  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-next-intl-locale", locale);

  return NextResponse.next({
    request: {
      headers: requestHeaders,
    },
  });
}
