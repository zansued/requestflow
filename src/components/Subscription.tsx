```typescript
// src/types/Subscription.ts
export interface Subscription {
    id: string; // Identificador único da assinatura
    userId: string; // ID do usuário associado a esta assinatura
    plan: string; // Plano de assinatura (por exemplo, "Mensal", "Anual")
    status: 'active' | 'cancelled' | 'suspended'; // Status atual da assinatura
    createdAt: Date; // Data de criação da assinatura
    updatedAt: Date; // Data da última atualização
}

// src/services/subscriptionService.ts
import { Subscription } from '../types/Subscription';

// Simulação de banco de dados
const database: Subscription[] = [];

export async function createSubscription(userId: string, plan: string): Promise<Subscription> {
    // Verificação se o usuário existe no mock de usuários
    if (!mockUsers.includes(userId)) {
        throw new Error('Usuário não encontrado.');
    }

    // Verifica se já existe uma assinatura ativa para o usuário
    const existingSubscription = database.find(sub => sub.userId === userId && sub.status === 'active');
    if (existingSubscription) {
        throw new Error('Usuário já possui uma assinatura ativa.');
    }

    // Criar uma nova assinatura
    const newSubscription: Subscription = {
        id: generateUniqueId(), // Função imaginária que gera um ID único
        userId,
        plan,
        status: 'active',
        createdAt: new Date(),
        updatedAt: new Date(),
    };

    database.push(newSubscription); // Simular a inserção no banco de dados
    return Promise.resolve(newSubscription);
}

export async function getSubscriptionByUserId(userId: string): Promise<Subscription | null> {
    const subscription = database.find(sub => sub.userId === userId && sub.status !== 'cancelled');
    return Promise.resolve(subscription || null); // Retorna a assinatura ou null
}

export async function updateSubscription(subscriptionId: string, updates: Partial<Subscription>): Promise<Subscription | null> {
    const subscriptionIndex = database.findIndex(sub => sub.id === subscriptionId);
    if (subscriptionIndex === -1) {
        throw new Error('Assinatura não encontrada.');
    }

    // Atualizar a assinatura
    const updatedSubscription: Subscription = {
        ...database[subscriptionIndex],
        ...updates,
        updatedAt: new Date(),
    };

    database[subscriptionIndex] = updatedSubscription; // Atualiza no "banco de dados"
    return Promise.resolve(updatedSubscription);
}

export async function deleteSubscription(subscriptionId: string): Promise<void> {
    const subscriptionIndex = database.findIndex(sub => sub.id === subscriptionId);
    if (subscriptionIndex === -1) {
        throw new Error('Assinatura não encontrada.');
    }

    database[subscriptionIndex].status = 'cancelled'; // Altera status em vez de deletar completamente
    return Promise.resolve();
}

function generateUniqueId(): string {
    return 'xxxx-xxxx-xxxx'.replace(/[x]/g, () => {
        return (Math.random() * 16 | 0).toString(16);
    });
}

// src/components/Subscription.tsx
import React, { useEffect, useState } from 'react';
import { Subscription } from '../types/Subscription';
import { createSubscription, getSubscriptionByUserId, updateSubscription, deleteSubscription } from '../services/subscriptionService';

const SubscriptionComponent: React.FC<{ userId: string }> = ({ userId }) => {
    const [subscription, setSubscription] = useState<Subscription | null>(null);
    const [plan, setPlan] = useState<string>('Mensal');
    const [status, setStatus] = useState<'active' | 'cancelled' | 'suspended'>('active');
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const fetchSubscription = async () => {
            try {
                const result = await getSubscriptionByUserId(userId);
                setSubscription(result);
            } catch (error) {
                setError('Erro ao buscar assinatura.');
            }
        };
        fetchSubscription();
    }, [userId]);

    const handleCreate = async () => {
        if (!plan || !userId) {
            setError('Usuário ou plano inválido.');
            return;
        }
        try {
            const newSubscription = await createSubscription(userId, plan);
            setSubscription(newSubscription);
            setError(null);
        } catch (error: any) {
            setError(error.message);
        }
    };

    const handleUpdate = async () => {
        if (subscription) {
            try {
                const updated = await updateSubscription(subscription.id, { plan, status });
                if (updated) {
                    setSubscription(updated);
                }
                setError(null);
            } catch (error: any) {
                setError(error.message);
            }
        }
    };

    const handleDelete = async () => {
        if (subscription) {
            try {
                await deleteSubscription(subscription.id);
                setSubscription(null);
                setError(null);
            } catch (error: any) {
                setError(error.message);
            }
        }
    };

    return (
        <div className="bg-white p-4 rounded shadow">
            <h2 className="text-lg font-semibold">Assinatura</h2>
            {error && <p className="text-red-500">{error}</p>}
            {subscription ? (
                <div>
                    <p>Plano: {subscription.plan}</p>
                    <p>Status: {subscription.status}</p>
                    <button onClick={handleUpdate} className="mt-2 bg-blue-500 text-white p-2 rounded">Atualizar</button>
                    <button onClick={handleDelete} className="mt-2 bg-red-500 text-white p-2 rounded">Cancelar</button>
                </div>
            ) : (
                <div>
                    <select value={plan} onChange={(e) => setPlan(e.target.value)} className="border p-2 rounded">
                        <option value="Mensal">Mensal</option>
                        <option value="Anual">Anual</option>
                    </select>
                    <button onClick={handleCreate} className="mt-2 bg-green-500 text-white p-2 rounded">Criar Assinatura</button>
                </div>
            )}
        </div>
    );
};

export default SubscriptionComponent;
```

### Resumo das Correções Implementadas
1. **Verificação de Assinaturas Existentes**: Adicionada uma lógica para verificar se o usuário já possui uma assinatura ativa antes de permitir a criação de uma nova.
2. **Geração de ID Único**: Implementada uma função para gerar IDs únicos ao criar uma nova assinatura.
3. **Operações de Atualização e Deleção**: Incluídas verificações para garantir que as assinaturas só possam ser atualizadas ou deletadas se existirem no sistema.
4. **Status de Cancelamento**: Ao invés de remover completamente a assinatura do “banco de dados”, o status é alterado para "cancelled".
5. **Tratamento de Erros Aprimorado**: Melhorias no tratamento de erros, garantindo um feedback mais claro ao usuário.