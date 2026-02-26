"use client";

import { useLocale, useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useTransition } from "react";
import LineItem from "@/refresh-components/buttons/LineItem";
import SvgGlobe from "@opal/icons/globe";
import { type Locale } from "@/i18n/routing";

const LOCALE_COOKIE = "NEXT_LOCALE";

function setLocaleCookie(locale: Locale) {
  // Set cookie that persists for 1 year, accessible from all paths
  document.cookie = `${LOCALE_COOKIE}=${locale}; path=/; max-age=${60 * 60 * 24 * 365}; SameSite=Lax`;
}

export default function LanguageSwitcher() {
  const locale = useLocale() as Locale;
  const router = useRouter();
  const [, startTransition] = useTransition();
  const t = useTranslations("languageSwitcher");

  const nextLocale: Locale = locale === "en" ? "ko" : "en";
  const label =
    locale === "en"
      ? `${t("english")} / ${t("korean")}`
      : `${t("korean")} / ${t("english")}`;

  const handleSwitch = () => {
    setLocaleCookie(nextLocale);
    startTransition(() => {
      router.refresh();
    });
  };

  return (
    <LineItem icon={SvgGlobe} onClick={handleSwitch}>
      {label}
    </LineItem>
  );
}
