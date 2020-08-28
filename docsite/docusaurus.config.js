module.exports = {
  title: 'Flutter Command',
  tagline: 'State management without a state',
  url: 'https://Abhilash-Chandran.github.io',
  baseUrl: '/flutter_command/',  
  favicon: 'img/favicon.ico',
  organizationName: 'Abhilash-Chandran', // Usually your GitHub org/user name.
  projectName: 'flutter_command', // Usually your repo name.  
  onBrokenLinks: 'throw',
  themeConfig: {
    prism: {
      additionalLanguages: ['dart'],
    },
    navbar: {
      title: 'Flutter Command',
      logo: {
        alt: 'My Site Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          to: 'docs/getting_started',
          activeBasePath: 'docs',
          label: 'Docs',
          position: 'left',
        },        
        {
          href: 'https://github.com/escamoteur/flutter_command',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Getting Started',
              to: 'docs/getting_started',
            },
            {
              label: 'CommandBuilder',
              to: 'docs/command_builder',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'Stack Overflow',
              href: 'https://stackoverflow.com/questions/tagged/docusaurus',
            },
            {
              label: 'Discord',
              href: 'https://discordapp.com/invite/docusaurus',
            },
            {
              label: 'Twitter',
              href: 'https://twitter.com/ThomasBurkhartB',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'Blog',
              href: 'https://www.burkharts.net/apps/blog/',
            },           
            {
              label: 'GitHub',
              href: 'https://github.com/escamoteur/flutter_command',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Thomas Bhurkart. Built with Docusaurus 2.`,
    },
  },
  presets: [
    [
      '@docusaurus/preset-classic',
      {
        docs: {
          // It is recommended to set document id as docs home page (`docs/` path).
          homePageId: '/',
          sidebarPath: require.resolve('./sidebars.js'),
          // Please change this to your repo.
          editUrl:
            'https://github.com/escamoteur/flutter_command',
        },        
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      },
    ],
  ],
};
