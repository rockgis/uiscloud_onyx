"use client";

import { useEffect } from "react";
import { toast } from "@/hooks/useToast";
import { useTranslations } from "next-intl";

export default function AuthErrorDisplay({
  searchParams,
}: {
  searchParams: any;
}) {
  const error = searchParams?.error;
  const t = useTranslations("auth");

  useEffect(() => {
    if (error) {
      if (error === "Anonymous") {
        toast.error(t("errors.anonymous"));
      } else {
        toast.error(t("errors.authError"));
      }
    }
  }, [error, t]);

  return null;
}
