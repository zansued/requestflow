```tsx
import React, { useEffect, useState, useContext } from 'react';
import { fetchSubscription, updateSubscription } from '../services/subscriptionService';
import { Subscription } from '../types/Subscription';
import { AuthContext } from '../context/AuthContext'; // Importando o contexto de autenticação

const SubscriptionPage: React.FC = () => {
    const { userId } = useContext(AuthContext); // Obtendo o userId do contexto de autenticação
    const [subscription, setSubscription] = useState<Subscription | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [newPlan, setNewPlan] = useState<string>('');
    const [successMessage, setSuccessMessage] = useState<string | null>(null);

    useEffect(() => {
        const loadSubscription = async () => {
            try {
                const sub = await fetchSubscription(userId);
                if (sub.status === 'inactive' || sub.status === 'cancelled') {
                    setError('Sua assinatura não está ativa. Você não pode modificar isso.');
                    return;
                }
                setSubscription(sub);
            } catch (err) {
                setError('Ocorreu um erro ao carregar sua assinatura.');
            } finally {
                setLoading(false);
            }
        };

        loadSubscription();
    }, [userId]);

    const isValidPlan = (plan: string) => {
        return plan.trim().length > 0; // Validação básica que garante que o plano não esteja vazio
    };

    const handleUpdate = async () => {
        if (isValidPlan(newPlan) && subscription) {
            setLoading(true);
            setError(null); // Resetando o erro ao tentar atualizar
            setSuccessMessage(null); // Resetando a mensagem de sucesso

            try {
                const updatedSubscription = await updateSubscription(userId, newPlan);
                setSubscription(updatedSubscription);
                setSuccessMessage('Sua assinatura foi atualizada com sucesso!'); // Mensagem de sucesso
                setNewPlan(''); // Limpando o campo após a atualização
            } catch (err) {
                setError('Erro ao atualizar a assinatura. Tente novamente.');
            } finally {
                setLoading(false);
            }
        } else {
            setError('Por favor, insira um plano válido.'); // Mensagem de erro se o plano não for válido
        }
    };

    if (loading) return <div>Carregando...</div>;
    if (error) return <div className="text-red-500">{error}</div>;

    return (
        <div className="p-4">
            <h1 className="text-2xl mb-4">Sua Assinatura</h1>
            {subscription && (
                <div className="mb-4">
                    <p><strong>Plano:</strong> {subscription.plan}</p>
                    <p><strong>Status:</strong> {subscription.status}</p>
                    <p><strong>Data de Início:</strong> {subscription.startDate.toLocaleDateString()}</p>
                    <p><strong>Data de Término:</strong> {subscription.endDate.toLocaleDateString()}</p>
                </div>
            )}
            {successMessage && <div className="text-green-500 mb-4">{successMessage}</div>} {/* Mensagem de sucesso */}
            <div>
                <h2 className="text-xl mb-2">Escolha um Novo Plano</h2>
                <input
                    type="text"
                    value={newPlan}
                    onChange={(e) => setNewPlan(e.target.value)}
                    className="border p-2 mb-2"
                    placeholder="Novo plano"
                />
                <button onClick={handleUpdate} className="bg-blue-500 text-white p-2 rounded">
                    Atualizar Assinatura
                </button>
            </div>
        </div>
    );
};

export default SubscriptionPage;
```

### Correções e Melhorias Implementadas:
1. **Remoção do Hardcoding do `userId`**: O `userId` agora é obtido a partir do contexto de autenticação (`AuthContext`), permitindo que ele seja dinâmico.
2. **Validação do Novo Plano**: Adicionada a função `isValidPlan` para garantir que o valor inserido não esteja vazio antes de atualizar a assinatura.
3. **Feedback Visual Após Atualização**: Foi incluída uma mensagem de sucesso após a atualização bem-sucedida da assinatura.
4. **Tratamento de Erros mais Robusto**: Reset do estado de erro antes de tentar a atualização e mensagens de erro mais específicas.
5. **Melhoria na Experiência do Usuário**: Inclui mensagens de sucesso e erros para que o usuário saiba o resultado das ações.