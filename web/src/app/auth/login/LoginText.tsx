"use client";

import React, { useContext } from "react";
import { SettingsContext } from "@/providers/SettingsProvider";
import Text from "@/refresh-components/texts/Text";
import { useTranslations } from "next-intl";

export default function LoginText() {
  const settings = useContext(SettingsContext);
  const t = useTranslations("auth");
  const appName =
    (settings && settings?.enterpriseSettings?.application_name) || "Onyx";
  return (
    <div className="w-full flex flex-col ">
      <Text as="p" headingH2 text05>
        {t("welcomeTo", { appName })}
      </Text>
      <Text as="p" text03 mainUiMuted>
        {t("aiPlatformSubtitle")}
      </Text>
    </div>
  );
}
