# SaaS Gerador de Roadmap com IA

Um sistema que utiliza IA para criar qualquer roadmap, tanto para aprendizado de programação, quanto para qualquer área do conhecimento.

## Stack Tecnológica

![Vite](https://img.shields.io/badge/vite-646CFF?style=for-the-badge&logo=vite&logoColor=white) 
![React](https://img.shields.io/badge/react-61DAFB?style=for-the-badge&logo=react&logoColor=black) 
![TypeScript](https://img.shields.io/badge/typescript-007ACC?style=for-the-badge&logo=typescript&logoColor=white)
![Tailwind CSS](https://img.shields.io/badge/tailwindCSS-06B6D4?style=for-the-badge&logo=tailwind-css&logoColor=white)
![Supabase](https://img.shields.io/badge/supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)

## Pré-requisitos

- [Node.js](https://nodejs.org/) (versão 14 ou superior)
- [npm](https://www.npmjs.com/) (geralmente incluído com Node.js)

## Instruções de Instalação

```bash
git clone https://github.com/seu-usuario/saas-gerador-roadmap.git
cd saas-gerador-roadmap
npm install
npm run dev
```

## Setup do Supabase

1. Copie o arquivo `.env.example` para `.env`.
2. Preencha `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` com as informações do seu projeto Supabase disponíveis em [Supabase](https://supa.techstorebrasil.com).
3. Execute as migrations SQL no dashboard do Supabase:
   - `supabase/migrations/create_users_table.sql`
   - `supabase/migrations/create_roadmaps_table.sql`
   - `supabase/migrations/create_rls_policies.sql`

## Scripts Disponíveis

- `npm run dev`: Inicia o servidor de desenvolvimento.
- `npm run build`: Cria a versão otimizada para produção.
- `npm run preview`: Exibe uma prévia da versão de produção.

## Deploy

Realize o deploy da aplicação com um clique na [Vercel](https://vercel.com) para facilitar a hospedagem.

## Licença

Este projeto está licenciado sob a Licença MIT. Consulte o arquivo [LICENSE](LICENSE) para mais detalhes.

---

Gerado pelo AxionOS