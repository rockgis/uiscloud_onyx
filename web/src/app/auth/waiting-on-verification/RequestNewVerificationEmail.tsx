"use client";

import { toast } from "@/hooks/useToast";
import { requestEmailVerification } from "../lib";
import { Spinner } from "@/components/Spinner";
import { useState, JSX } from "react";
import { useTranslations } from "next-intl";

export function RequestNewVerificationEmail({
  children,
  email,
}: {
  children: JSX.Element | string;
  email: string;
}) {
  const [isRequestingVerification, setIsRequestingVerification] =
    useState(false);
  const t = useTranslations("auth");

  return (
    <button
      className="text-link"
      onClick={async () => {
        setIsRequestingVerification(true);
        const response = await requestEmailVerification(email);
        setIsRequestingVerification(false);

        if (response.ok) {
          toast.success(t("verificationEmailSent"));
        } else {
          const errorDetail = (await response.json()).detail;
          toast.error(t("verificationEmailFailed", { detail: errorDetail }));
        }
      }}
    >
      {isRequestingVerification && <Spinner />}
      {children}
    </button>
  );
}
