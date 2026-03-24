"use client";

import { ThreeDotsLoader } from "@/components/Loading";
import { AdminPageTitle } from "@/components/admin/Title";
import { errorHandlingFetcher } from "@/lib/fetcher";
import Text from "@/components/ui/text";
import Title from "@/components/ui/title";
import Button from "@/refresh-components/buttons/Button";
import useSWR from "swr";
import { ModelPreview } from "@/components/embedding/ModelSelector";
import {
  HostedEmbeddingModel,
  CloudEmbeddingModel,
} from "@/components/embedding/interfaces";
import { SavedSearchSettings } from "@/app/admin/embeddings/interfaces";
import UpgradingPage from "./UpgradingPage";
import { useContext } from "react";
import { SettingsContext } from "@/providers/SettingsProvider";
import CardSection from "@/components/admin/CardSection";
import { ErrorCallout } from "@/components/ErrorCallout";
import { useToastFromQuery } from "@/hooks/useToast";
import { SvgSearch } from "@opal/icons";
import { useTranslations } from "next-intl";

export interface EmbeddingDetails {
  api_key: string;
  custom_config: any;
  default_model_id?: number;
  name: string;
}

function Main() {
  const t = useTranslations("admin");
  const settings = useContext(SettingsContext);
  useToastFromQuery({
    "search-settings": {
      message: `Changed search settings successfully`,
      type: "success",
    },
  });
  const {
    data: currentEmeddingModel,
    isLoading: isLoadingCurrentModel,
    error: currentEmeddingModelError,
  } = useSWR<CloudEmbeddingModel | HostedEmbeddingModel | null>(
    "/api/search-settings/get-current-search-settings",
    errorHandlingFetcher,
    { refreshInterval: 5000 } // 5 seconds
  );

  const { data: searchSettings, isLoading: isLoadingSearchSettings } =
    useSWR<SavedSearchSettings | null>(
      "/api/search-settings/get-current-search-settings",
      errorHandlingFetcher,
      { refreshInterval: 5000 } // 5 seconds
    );

  const {
    data: futureEmbeddingModel,
    isLoading: isLoadingFutureModel,
    error: futureEmeddingModelError,
  } = useSWR<CloudEmbeddingModel | HostedEmbeddingModel | null>(
    "/api/search-settings/get-secondary-search-settings",
    errorHandlingFetcher,
    { refreshInterval: 5000 } // 5 seconds
  );

  if (
    isLoadingCurrentModel ||
    isLoadingFutureModel ||
    isLoadingSearchSettings
  ) {
    return <ThreeDotsLoader />;
  }

  if (
    currentEmeddingModelError ||
    !currentEmeddingModel ||
    futureEmeddingModelError
  ) {
    return <ErrorCallout errorTitle="Failed to fetch embedding model status" />;
  }

  return (
    <div>
      {!futureEmbeddingModel ? (
        <>
          {settings?.settings.needs_reindexing && (
            <p className="max-w-3xl">{t("searchSettingsOutOfDate")}</p>
          )}
          <Title className="mb-6 mt-8 !text-2xl">{t("embeddingModel")}</Title>

          {currentEmeddingModel ? (
            <ModelPreview model={currentEmeddingModel} display showDetails />
          ) : (
            <Title className="mt-8 mb-4">Choose your Embedding Model</Title>
          )}

          <Title className="mb-2 mt-8 !text-2xl">{t("postProcessing")}</Title>

          <CardSection className="!mr-auto mt-8 !w-96 shadow-lg bg-background-tint-00 rounded-16">
            {searchSettings && (
              <>
                <div className="px-1 w-full rounded-lg">
                  <div className="space-y-4">
                    <div>
                      <Text className="font-semibold">
                        {t("multipassIndexing")}
                      </Text>
                      <Text className="text-text-700">
                        {searchSettings.multipass_indexing
                          ? t("enabled")
                          : t("disabled")}
                      </Text>
                    </div>

                    <div>
                      <Text className="font-semibold">
                        {t("contextualRag")}
                      </Text>
                      <Text className="text-text-700">
                        {searchSettings.enable_contextual_rag
                          ? t("enabled")
                          : t("disabled")}
                      </Text>
                    </div>
                  </div>
                </div>
              </>
            )}
          </CardSection>

          <div className="mt-4">
            <Button action href="/admin/embeddings">
              {t("updateSearchSettings")}
            </Button>
          </div>
        </>
      ) : (
        <UpgradingPage futureEmbeddingModel={futureEmbeddingModel} />
      )}
    </div>
  );
}

export default function Page() {
  const t = useTranslations("admin");
  return (
    <>
      <AdminPageTitle title={t("searchSettings")} icon={SvgSearch} />
      <Main />
    </>
  );
}
