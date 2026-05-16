import { themes as prismThemes } from "prism-react-renderer";
import type { Config } from "@docusaurus/types";
import type * as Preset from "@docusaurus/preset-classic";
import type * as OpenApiPlugin from "docusaurus-plugin-openapi-docs";

const config: Config = {
  title: "TPA Stream Developer Documentation",
  tagline: "REST API, Webhooks, and the Connect SDK",
  favicon: "img/logo.png",

  url: "https://developers.tpastream.com",
  baseUrl: "/",

  organizationName: "LakeEriePartners",
  projectName: "developer-docs",

  onBrokenLinks: "warn",
  onBrokenMarkdownLinks: "warn",
  onBrokenAnchors: "warn",

  i18n: {
    defaultLocale: "en",
    locales: ["en"],
  },

  clientModules: ["./src/clientModules/legacy-anchor-redirects.ts"],

  presets: [
    [
      "classic",
      {
        docs: {
          routeBasePath: "/",
          sidebarPath: "./sidebars.ts",
          editUrl:
            "https://github.com/LakeEriePartners/developer-docs/edit/master/",
          docItemComponent: "@theme/ApiItem",
        },
        blog: false,
        theme: {
          customCss: "./src/css/custom.css",
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: "img/logo.png",
    colorMode: {
      defaultMode: "light",
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: "TPA Stream",
      logo: {
        alt: "TPA Stream",
        src: "img/logo.png",
        srcDark: "img/logo-white.png",
      },
      items: [
        { to: "/getting-started", label: "Getting Started", position: "left" },
        { to: "/connect/overview", label: "Connect SDK", position: "left" },
        { to: "/api/overview", label: "REST API", position: "left" },
        {
          to: "/api-reference/tpa-stream-api",
          label: "API Reference",
          position: "left",
        },
        { to: "/sdk/", label: "SDK Reference", position: "left" },
        {
          href: "https://app.tpastream.com/rapidoc",
          label: "RapiDoc",
          position: "right",
        },
        {
          href: "https://github.com/TPAStream/stream-connect-js-sdk",
          label: "GitHub",
          position: "right",
        },
      ],
    },
    footer: {
      style: "dark",
      links: [
        {
          title: "Docs",
          items: [
            { label: "Getting Started", to: "/getting-started" },
            { label: "REST API", to: "/api/overview" },
            { label: "Connect SDK", to: "/connect/overview" },
          ],
        },
        {
          title: "Reference",
          items: [
            { label: "API Reference", to: "/api-reference/tpa-stream-api" },
            { label: "SDK Reference", to: "/sdk/" },
            {
              label: "OpenAPI Spec",
              href: "https://app.tpastream.com/openapi.json",
            },
          ],
        },
        {
          title: "More",
          items: [
            { label: "Sign in", href: "https://app.tpastream.com/login" },
            {
              label: "Connect SDK on npm",
              href: "https://www.npmjs.com/package/stream-connect-sdk",
            },
            {
              label: "Privacy Policy",
              href: "https://app.tpastream.com/privacy",
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} TPA Stream, Inc.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ["bash", "json", "python", "java", "objectivec"],
    },
  } satisfies Preset.ThemeConfig,

  plugins: [
    [
      "docusaurus-plugin-openapi-docs",
      {
        id: "openapi",
        docsPluginId: "classic",
        config: {
          tpastream: {
            specPath: "openapi/tpastream-api.json",
            outputDir: "docs/api-reference",
            sidebarOptions: {
              groupPathsBy: "tag",
              categoryLinkSource: "tag",
            },
            downloadUrl:
              "https://app.tpastream.com/openapi.json",
            hideSendButton: false,
            showSchemas: true,
          } satisfies OpenApiPlugin.Options,
        },
      },
    ],
    [
      "@easyops-cn/docusaurus-search-local",
      {
        hashed: true,
        docsRouteBasePath: "/",
        indexBlog: false,
        highlightSearchTermsOnTargetPage: true,
      },
    ],
  ],

  themes: ["docusaurus-theme-openapi-docs"],
};

export default config;
