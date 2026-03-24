"use client";

import { SvgImage } from "@opal/icons";
import * as SettingsLayouts from "@/layouts/settings-layouts";
import ImageGenerationContent from "./ImageGenerationContent";
import { useTranslations } from "next-intl";

export default function Page() {
  const t = useTranslations("admin");
  return (
    <SettingsLayouts.Root>
      <SettingsLayouts.Header
        icon={SvgImage}
        title={t("imageGeneration")}
        description={t("imageGenerationDescription")}
      />
      <SettingsLayouts.Body>
        <ImageGenerationContent />
      </SettingsLayouts.Body>
    </SettingsLayouts.Root>
  );
}
