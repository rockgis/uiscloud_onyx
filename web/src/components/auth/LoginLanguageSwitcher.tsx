"use client";

import { useLocale } from "next-intl";
import { useRouter } from "next/navigation";
import { useTransition } from "react";
import { cn } from "@/lib/utils";
import { type Locale } from "@/i18n/routing";

const LOCALE_COOKIE = "NEXT_LOCALE";

function setLocaleCookie(locale: Locale) {
  document.cookie = `${LOCALE_COOKIE}=${locale}; path=/; max-age=${60 * 60 * 24 * 365}; SameSite=Lax`;
}

interface LocaleButtonProps {
  label: string;
  isActive: boolean;
  onClick: () => void;
}

function LocaleButton({ label, isActive, onClick }: LocaleButtonProps) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "px-2 py-0.5 rounded text-xs font-medium transition-colors",
        isActive
          ? "bg-background-neutral-03 text-text-01"
          : "text-text-03 hover:text-text-01"
      )}
    >
      {label}
    </button>
  );
}

export default function LoginLanguageSwitcher() {
  const locale = useLocale() as Locale;
  const router = useRouter();
  const [, startTransition] = useTransition();

  const handleSelect = (nextLocale: Locale) => {
    if (nextLocale === locale) return;
    setLocaleCookie(nextLocale);
    startTransition(() => {
      router.refresh();
    });
  };

  return (
    <div className="flex items-center gap-0.5 border border-border-02 rounded-08 p-0.5">
      <LocaleButton
        label="EN"
        isActive={locale === "en"}
        onClick={() => handleSelect("en")}
      />
      <span className="text-border-03 text-xs select-none">|</span>
      <LocaleButton
        label="KO"
        isActive={locale === "ko"}
        onClick={() => handleSelect("ko")}
      />
    </div>
  );
}
