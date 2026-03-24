"use client";

import { AdminPageTitle } from "@/components/admin/Title";
import { LLMConfiguration } from "./LLMConfiguration";
import { SvgCpu } from "@opal/icons";
import { useTranslations } from "next-intl";

export default function Page() {
  const t = useTranslations("admin");
  return (
    <>
      <AdminPageTitle title={t("llmSetup")} icon={SvgCpu} />

      <LLMConfiguration />
    </>
  );
}
