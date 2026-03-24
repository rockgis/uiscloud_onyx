"use client";

import { ErrorCallout } from "@/components/ErrorCallout";
import { ThreeDotsLoader } from "@/components/Loading";
import { InstantSSRAutoRefresh } from "@/components/SSRAutoRefresh";
import { AdminPageTitle } from "@/components/admin/Title";
import { SourceIcon } from "@/components/SourceIcon";
import { SlackBotTable } from "./SlackBotTable";
import { useSlackBots } from "./[bot-id]/hooks";
import { ValidSources } from "@/lib/types";
import CreateButton from "@/refresh-components/buttons/CreateButton";
import { DOCS_ADMINS_PATH } from "@/lib/constants";
import { useTranslations } from "next-intl";

const Main = () => {
  const t = useTranslations("admin");
  const {
    data: slackBots,
    isLoading: isSlackBotsLoading,
    error: slackBotsError,
  } = useSlackBots();

  if (isSlackBotsLoading) {
    return <ThreeDotsLoader />;
  }

  if (slackBotsError || !slackBots) {
    const errorMsg =
      slackBotsError?.info?.message ||
      slackBotsError?.info?.detail ||
      "An unknown error occurred";

    return (
      <ErrorCallout
        errorTitle={t("errorLoadingApps")}
        errorMsg={`${errorMsg}`}
      />
    );
  }

  return (
    <div className="mb-8">
      <p className="mb-2 text-sm text-muted-foreground">{t("slackBotsSetup")}</p>

      <div className="mb-2">
        <ul className="list-disc mt-2 ml-4 text-sm text-muted-foreground">
          <li>{t("slackBotsAutoAnswer")}</li>
          <li>{t("slackBotsDocSets")}</li>
          <li>{t("slackBotsDirectMessage")}</li>
        </ul>
      </div>

      <p className="mb-6 text-sm text-muted-foreground">
        {t.rich("slackBotsGuide", {
          guideLink: (chunks) => (
            <a
              className="text-blue-500 hover:underline"
              href={`${DOCS_ADMINS_PATH}/getting_started/slack_bot_setup`}
              target="_blank"
              rel="noopener noreferrer"
            >
              {chunks}
            </a>
          ),
        })}
      </p>

      <CreateButton href="/admin/bots/new">{t("newSlackBot")}</CreateButton>

      <SlackBotTable slackBots={slackBots} />
    </div>
  );
};

const Page = () => {
  const t = useTranslations("admin");
  return (
    <>
      <AdminPageTitle
        icon={<SourceIcon iconSize={36} sourceType={ValidSources.Slack} />}
        title={t("slackBots")}
      />
      <InstantSSRAutoRefresh />

      <Main />
    </>
  );
};

export default Page;
