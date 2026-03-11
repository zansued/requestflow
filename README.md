# AxionOS Landing

Uma landing page moderna que apresenta o AxionOS, um sistema de engenharia autônomo que transforma ideias em software funcional usando agentes de IA inteligentes, reduzindo o tempo de desenvolvimento desde o conceito até o produto.

## Stack Tecnológica
![Vite](https://img.shields.io/badge/Vite-646CFF?style=flat&logo=vite&logoColor=ffffff) ![React](https://img.shields.io/badge/React-61DAFB?style=flat&logo=react&logoColor=black) ![TypeScript](https://img.shields.io/badge/TypeScript-007ACC?style=flat&logo=typescript&logoColor=white) ![Tailwind CSS](https://img.shields.io/badge/Tailwind%20CSS-06B6D4?style=flat&logo=tailwind-css&logoColor=white) ![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=flat&logo=supabase&logoColor=white)

## Pré-requisitos
- [Node.js](https://nodejs.org) (>= 14.x)
- [npm](https://www.npmjs.com/) (>= 6.x)

## Instruções de Instalação
```bash
git clone https://github.com/seu-usuario/axionos-landing.git
cd axionos-landing
npm install
npm run dev
```

## Setup do Supabase
1. Copie `.env.example` para `.env`.
2. Preencha `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` com suas credenciais do Supabase.
3. Execute as migrations SQL no dashboard do Supabase:
   - `supabase/migrations/001_create_early_access_signups.sql`
   - `supabase/migrations/002_create_testimonials.sql`
   - `supabase/migrations/003_create_analytics_events.sql`
   - `supabase/migrations/004_setup_rls_policies.sql`

## Scripts Disponíveis
- `npm run dev`: Inicia o servidor de desenvolvimento.
- `npm run build`: Gera uma versão de produção.
- `npm run preview`: Visualiza a versão de produção localmente.

## Deploy
Faça o deploy facilmente com [Vercel](https://vercel.com) clicando em "Deploy with Vercel".

## Licença
MIT

---

Gerado pelo AxionOS