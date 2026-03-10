# RequestFlow

RequestFlow é um sistema interno baseado na web para gerenciamento de solicitações e aprovações em organizações, permitindo que usuários submetam requisições e gerentes aprovem, rejeitem ou solicitem ajustes, com um completo rastreamento de auditoria.

## Stack Tecnológica

![Vite](https://img.shields.io/badge/Vite-%23EA4A3A.svg?style=for-the-badge&logo=vite&logoColor=white) 
![React](https://img.shields.io/badge/React-%2361DAFB.svg?style=for-the-badge&logo=react&logoColor=white) 
![TypeScript](https://img.shields.io/badge/TypeScript-%233178C6.svg?style=for-the-badge&logo=typescript&logoColor=white) 
![Tailwind CSS](https://img.shields.io/badge/Tailwind%20CSS-%2338B2F5.svg?style=for-the-badge&logo=tailwind-css&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-%2337B24D.svg?style=for-the-badge&logo=supabase&logoColor=white)

## Pré-requisitos

- Node.js
- npm

## Instruções de Instalação

```bash
git clone https://github.com/seu_usuario/requestflow.git
cd requestflow
npm install
npm run dev
```

## Setup do Supabase

1. Copie `.env.example` para `.env`.
2. Preencha `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY`.
3. Execute as migrations SQL no dashboard do Supabase:

   - `supabase/migrations/003_templates_schema.sql`
   - `supabase/migrations/002_rls_policies.sql`
   - `supabase/migrations/004_requests_schema.sql`

## Scripts Disponíveis

- `dev` - Inicia o servidor de desenvolvimento.
- `build` - Compila o projeto para produção.
- `preview` - Visualiza o projeto em produção localmente.

## Deploy

Deploy fácil para Vercel com apenas um clique. Siga as instruções na documentação de Vercel.

## Licença

Este projeto está licenciado sob a Licença MIT. Consulte o arquivo [LICENSE](LICENSE) para mais detalhes.

---

Gerado pelo AxionOS