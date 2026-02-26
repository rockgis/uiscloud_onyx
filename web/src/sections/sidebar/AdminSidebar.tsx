"use client";

import { usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import { useSettingsContext } from "@/providers/SettingsProvider";
import { CgArrowsExpandUpLeft } from "react-icons/cg";
import Text from "@/refresh-components/texts/Text";
import SidebarSection from "@/sections/sidebar/SidebarSection";
import SidebarWrapper from "@/sections/sidebar/SidebarWrapper";
import { useIsKGExposed } from "@/app/admin/kg/utils";
import { useCustomAnalyticsEnabled } from "@/lib/hooks/useCustomAnalyticsEnabled";
import { useUser } from "@/providers/UserProvider";
import { UserRole } from "@/lib/types";
import {
  useBillingInformation,
  useLicense,
  hasActiveSubscription,
} from "@/lib/billing";
import { usePaidEnterpriseFeaturesEnabled } from "@/components/settings/usePaidEnterpriseFeaturesEnabled";
import {
  ClipboardIcon,
  NotebookIconSkeleton,
  SlackIconSkeleton,
  BrainIcon,
} from "@/components/icons/icons";
import { CombinedSettings } from "@/interfaces/settings";
import SidebarTab from "@/refresh-components/buttons/SidebarTab";
import SidebarBody from "@/sections/sidebar/SidebarBody";
import {
  SvgActions,
  SvgActivity,
  SvgArrowUpCircle,
  SvgBarChart,
  SvgBubbleText,
  SvgCpu,
  SvgFileText,
  SvgFolder,
  SvgGlobe,
  SvgArrowExchange,
  SvgImage,
  SvgKey,
  SvgOnyxOctagon,
  SvgSearch,
  SvgServer,
  SvgShield,
  SvgThumbsUp,
  SvgUploadCloud,
  SvgUser,
  SvgUsers,
  SvgZoomIn,
  SvgPaintBrush,
  SvgDiscordMono,
  SvgWallet,
} from "@opal/icons";
import SvgMcp from "@opal/icons/mcp";
import UserAvatarPopover from "@/sections/sidebar/UserAvatarPopover";

type TFn = (key: string) => string;

const connectors_items = (t: TFn) => [
  {
    name: t("existingConnectors"),
    icon: NotebookIconSkeleton,
    link: "/admin/indexing/status",
  },
  {
    name: t("addConnector"),
    icon: SvgUploadCloud,
    link: "/admin/add-connector",
  },
];

const document_management_items = (t: TFn) => [
  {
    name: t("documentSets"),
    icon: SvgFolder,
    link: "/admin/documents/sets",
  },
  {
    name: t("explorer"),
    icon: SvgZoomIn,
    link: "/admin/documents/explorer",
  },
  {
    name: t("feedback"),
    icon: SvgThumbsUp,
    link: "/admin/documents/feedback",
  },
];

const custom_assistants_items = (
  isCurator: boolean,
  enableEnterprise: boolean,
  t: TFn
) => {
  const items = [
    {
      name: t("assistants"),
      icon: SvgOnyxOctagon,
      link: "/admin/assistants",
    },
  ];

  if (!isCurator) {
    items.push(
      {
        name: t("slackBots"),
        icon: SlackIconSkeleton,
        link: "/admin/bots",
      },
      {
        name: t("discordBots"),
        icon: SvgDiscordMono,
        link: "/admin/discord-bot",
      }
    );
  }

  items.push(
    {
      name: t("mcpActions"),
      icon: SvgMcp,
      link: "/admin/actions/mcp",
    },
    {
      name: t("openApiActions"),
      icon: SvgActions,
      link: "/admin/actions/open-api",
    }
  );

  if (enableEnterprise) {
    items.push({
      name: t("standardAnswers"),
      icon: ClipboardIcon,
      link: "/admin/standard-answer",
    });
  }

  return items;
};

const collections = (
  isCurator: boolean,
  enableCloud: boolean,
  enableEnterprise: boolean,
  settings: CombinedSettings | null,
  kgExposed: boolean,
  customAnalyticsEnabled: boolean,
  hasSubscription: boolean,
  t: TFn
) => {
  const vectorDbEnabled = settings?.settings.vector_db_enabled !== false;

  return [
    ...(vectorDbEnabled
      ? [
          {
            name: t("connectors"),
            items: connectors_items(t),
          },
        ]
      : []),
    ...(vectorDbEnabled
      ? [
          {
            name: t("documentManagement"),
            items: document_management_items(t),
          },
        ]
      : []),
    {
      name: t("customAssistants"),
      items: custom_assistants_items(isCurator, enableEnterprise, t),
    },
    ...(isCurator && enableEnterprise
      ? [
          {
            name: t("userManagement"),
            items: [
              {
                name: t("groups"),
                icon: SvgUsers,
                link: "/admin/groups",
              },
            ],
          },
        ]
      : []),
    ...(!isCurator
      ? [
          {
            name: t("configuration"),
            items: [
              {
                name: t("chatPreferences"),
                icon: SvgBubbleText,
                link: "/admin/configuration/chat-preferences",
              },
              {
                name: t("llm"),
                icon: SvgCpu,
                link: "/admin/configuration/llm",
              },
              {
                name: t("webSearch"),
                icon: SvgGlobe,
                link: "/admin/configuration/web-search",
              },
              {
                name: t("imageGeneration"),
                icon: SvgImage,
                link: "/admin/configuration/image-generation",
              },
              ...(!enableCloud && vectorDbEnabled
                ? [
                    {
                      error: settings?.settings.needs_reindexing,
                      name: t("searchSettings"),
                      icon: SvgSearch,
                      link: "/admin/configuration/search",
                    },
                  ]
                : []),
              {
                name: t("documentProcessing"),
                icon: SvgFileText,
                link: "/admin/configuration/document-processing",
              },
              ...(kgExposed
                ? [
                    {
                      name: t("knowledgeGraph"),
                      icon: BrainIcon,
                      link: "/admin/kg",
                    },
                  ]
                : []),
            ],
          },
          {
            name: t("userManagement"),
            items: [
              {
                name: t("users"),
                icon: SvgUser,
                link: "/admin/users",
              },
              ...(enableEnterprise
                ? [
                    {
                      name: t("groups"),
                      icon: SvgUsers,
                      link: "/admin/groups",
                    },
                  ]
                : []),
              {
                name: t("apiKeys"),
                icon: SvgKey,
                link: "/admin/api-key",
              },
              {
                name: t("tokenRateLimits"),
                icon: SvgShield,
                link: "/admin/token-rate-limits",
              },
            ],
          },
          ...(enableEnterprise
            ? [
                {
                  name: t("performance"),
                  items: [
                    {
                      name: t("usageStatistics"),
                      icon: SvgActivity,
                      link: "/admin/performance/usage",
                    },
                    ...(settings?.settings.query_history_type !== "disabled"
                      ? [
                          {
                            name: t("queryHistory"),
                            icon: SvgServer,
                            link: "/admin/performance/query-history",
                          },
                        ]
                      : []),
                    ...(!enableCloud && customAnalyticsEnabled
                      ? [
                          {
                            name: t("customAnalytics"),
                            icon: SvgBarChart,
                            link: "/admin/performance/custom-analytics",
                          },
                        ]
                      : []),
                  ],
                },
              ]
            : []),
          {
            name: t("settings"),
            items: [
              ...(enableEnterprise
                ? [
                    {
                      name: t("appearanceTheming"),
                      icon: SvgPaintBrush,
                      link: "/admin/theme",
                    },
                  ]
                : []),
              // Always show billing/upgrade - community users need access to upgrade
              {
                name: hasSubscription ? t("plansBilling") : t("upgradePlan"),
                icon: hasSubscription ? SvgWallet : SvgArrowUpCircle,
                link: "/admin/billing",
              },
              ...(settings?.settings.opensearch_indexing_enabled
                ? [
                    {
                      name: t("documentIndexMigration"),
                      icon: SvgArrowExchange,
                      link: "/admin/document-index-migration",
                    },
                  ]
                : []),
            ],
          },
        ]
      : []),
  ];
};

interface AdminSidebarProps {
  // Cloud flag is passed from server component (Layout.tsx) since it's a build-time constant
  enableCloudSS: boolean;
  // Enterprise flag is also passed but we override it with runtime license check below
  enableEnterpriseSS: boolean;
}

export default function AdminSidebar({
  enableCloudSS,
  enableEnterpriseSS,
}: AdminSidebarProps) {
  const t = useTranslations("admin");
  const tSidebar = useTranslations("sidebar");
  const { kgExposed } = useIsKGExposed();
  const pathname = usePathname();
  const { customAnalyticsEnabled } = useCustomAnalyticsEnabled();
  const { user } = useUser();
  const settings = useSettingsContext();
  const { data: billingData } = useBillingInformation();
  const { data: licenseData } = useLicense();

  // Use runtime license check for enterprise features
  // This checks settings.ee_features_enabled (set by backend based on license status)
  // Falls back to build-time check if LICENSE_ENFORCEMENT_ENABLED=false
  const enableEnterprise = usePaidEnterpriseFeaturesEnabled();

  const isCurator =
    user?.role === UserRole.CURATOR || user?.role === UserRole.GLOBAL_CURATOR;

  // Check if user has an active subscription or license for billing link text
  // Show "Plans & Billing" if they have either (even if Stripe connection fails)
  const hasSubscription = Boolean(
    (billingData && hasActiveSubscription(billingData)) ||
      licenseData?.has_license
  );

  const items = collections(
    isCurator,
    enableCloudSS,
    enableEnterprise,
    settings,
    kgExposed,
    customAnalyticsEnabled,
    hasSubscription,
    t as TFn
  );

  return (
    <SidebarWrapper>
      <SidebarBody
        scrollKey="admin-sidebar"
        actionButtons={
          <SidebarTab
            leftIcon={({ className }) => (
              <CgArrowsExpandUpLeft className={className} size={16} />
            )}
            href="/app"
          >
            {tSidebar("exitAdmin")}
          </SidebarTab>
        }
        footer={
          <div className="flex flex-col gap-2">
            {settings.webVersion && (
              <Text as="p" text02 secondaryBody className="px-2">
                {tSidebar("onyxVersion", { version: settings.webVersion })}
              </Text>
            )}
            <UserAvatarPopover />
          </div>
        }
      >
        {items.map((collection, index) => (
          <SidebarSection key={index} title={collection.name}>
            <div className="flex flex-col w-full">
              {collection.items.map(({ link, icon: Icon, name }, index) => (
                <SidebarTab
                  key={index}
                  href={link}
                  transient={pathname.startsWith(link)}
                  leftIcon={({ className }) => (
                    <Icon className={className} size={16} />
                  )}
                >
                  {name}
                </SidebarTab>
              ))}
            </div>
          </SidebarSection>
        ))}
      </SidebarBody>
    </SidebarWrapper>
  );
}
