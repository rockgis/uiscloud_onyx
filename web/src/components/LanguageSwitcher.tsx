"use client";

import { useLocale, useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useTransition } from "react";
import LineItem from "@/refresh-components/buttons/LineItem";
import SvgGlobe from "@opal/icons/globe";
import SvgCheck from "@opal/icons/check";
import { type Locale } from "@/i18n/routing";

const LOCALE_COOKIE = "NEXT_LOCALE";

function setLocaleCookie(locale: Locale) {
  document.cookie = `${LOCALE_COOKIE}=${locale}; path=/; max-age=${60 * 60 * 24 * 365}; SameSite=Lax`;
}

interface LanguageOptionProps {
  locale: Locale;
  label: string;
  isActive: boolean;
  onSelect: (locale: Locale) => void;
}

function LanguageOption({
  locale,
  label,
  isActive,
  onSelect,
}: LanguageOptionProps) {
  return (
    <LineItem
      icon={SvgGlobe}
      selected={isActive}
      emphasized={isActive}
      onClick={() => onSelect(locale)}
      rightChildren={
        isActive ? (
          <SvgCheck size={16} className="stroke-action-link-05" />
        ) : undefined
      }
    >
      {label}
    </LineItem>
  );
}

export default function LanguageSwitcher() {
  const locale = useLocale() as Locale;
  const router = useRouter();
  const [, startTransition] = useTransition();
  const t = useTranslations("common");

  const handleSelect = (nextLocale: Locale) => {
    if (nextLocale === locale) return;
    setLocaleCookie(nextLocale);
    startTransition(() => {
      router.refresh();
    });
  };

  return (
    <div>
      <LanguageOption
        locale="en"
        label={t("english")}
        isActive={locale === "en"}
        onSelect={handleSelect}
      />
      <LanguageOption
        locale="ko"
        label={t("korean")}
        isActive={locale === "ko"}
        onSelect={handleSelect}
      />
    </div>
  );
}
