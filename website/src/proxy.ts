import { getPreferredLocale, isLocale } from "@/i18n/config";
import { NextResponse, type NextRequest } from "next/server";

export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const firstSegment = pathname.split("/")[1];

  if (firstSegment && isLocale(firstSegment)) {
    const headers = new Headers(request.headers);
    headers.set("x-phototend-locale", firstSegment);
    return NextResponse.next({ request: { headers } });
  }

  if (pathname === "/") {
    const locale = getPreferredLocale(request.headers.get("accept-language"));
    return NextResponse.redirect(new URL(`/${locale}`, request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico|.*\\..*).*)"],
};
