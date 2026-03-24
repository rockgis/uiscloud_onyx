import Link from "next/link";
import { OnyxIcon } from "../icons/icons";
import LoginLanguageSwitcher from "./LoginLanguageSwitcher";
import { getTranslations } from "next-intl/server";

export default async function AuthFlowContainer({
  children,
  authState,
  footerContent,
}: {
  children: React.ReactNode;
  authState?: "signup" | "login" | "join";
  footerContent?: React.ReactNode;
}) {
  const t = await getTranslations("auth");

  return (
    <div className="p-4 flex flex-col items-center justify-center min-h-screen bg-background">
      <div className="w-full max-w-md flex items-start flex-col bg-background-tint-00 rounded-16 shadow-lg shadow-02 p-6">
        <div className="flex items-center justify-between w-full">
          <OnyxIcon size={44} className="text-theme-primary-05" />
          <LoginLanguageSwitcher />
        </div>
        <div className="w-full mt-3">{children}</div>
      </div>
      {authState === "login" && (
        <div className="text-sm mt-6 text-center w-full text-text-03 mainUiBody mx-auto">
          {footerContent ?? (
            <>
              {t("newToOnyx")}{" "}
              <Link
                href="/auth/signup"
                className="text-text-05 mainUiAction underline transition-colors duration-200"
              >
                {t("createAccount")}
              </Link>
            </>
          )}
        </div>
      )}
      {authState === "signup" && (
        <div className="text-sm mt-6 text-center w-full text-text-03 mainUiBody mx-auto">
          {t("alreadyHaveAccount")}{" "}
          <Link
            href="/auth/login?autoRedirectToSignup=false"
            className="text-text-05 mainUiAction underline transition-colors duration-200"
          >
            {t("signIn")}
          </Link>
        </div>
      )}
    </div>
  );
}
