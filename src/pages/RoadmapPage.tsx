```tsx
import React, { useEffect, useState } from 'react';
import { fetchRoadmap } from '../services/roadmapService';
import { Roadmap } from '../types/Roadmap';

const RoadmapPage: React.FC<{ roadmapId: string }> = ({ roadmapId }) => {
    const [roadmap, setRoadmap] = useState<Roadmap | null>(null);
    const [loading, setLoading] = useState<boolean>(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const loadRoadmap = async () => {
            // Validação do roadmapId antes de buscar
            if (!roadmapId || !/^[a-fA-F0-9]{24}$/.test(roadmapId)) {
                setError('ID do roadmap inválido. Deve ser um ID de formato hexadecimal.');
                setLoading(false);
                return;
            }

            try {
                const fetchedRoadmap = await fetchRoadmap(roadmapId);
                if (!fetchedRoadmap) {
                    setError('Roadmap não encontrado.');
                } else {
                    setRoadmap(fetchedRoadmap);
                }
            } catch (err) {
                const errorMessage = (err as Error).message || 'Erro desconhecido';
                setError(`Erro ao carregar o roadmap: ${errorMessage}`);
            } finally {
                setLoading(false);
            }
        };

        loadRoadmap();
    }, [roadmapId]);

    if (loading) {
        return <div className="flex justify-center items-center h-screen"><p>Carregando...</p></div>;
    }

    if (error) {
        return <div className="text-red-500 text-center">{error}</div>;
    }

    return (
        <div className="container mx-auto p-4">
            <h1 className="text-2xl font-bold">{roadmap?.titulo}</h1>
            <p className="mt-2">{roadmap?.descricao}</p>
            <h2 className="text-xl mt-4">Conteúdos:</h2>
            {roadmap && roadmap.conteudos && roadmap.conteudos.length > 0 ? (
                <ul className="list-disc pl-5">
                    {roadmap.conteudos.map(conteudo => (
                        <li key={conteudo.id} className="mt-2">
                            <a href={conteudo.link} target="_blank" rel="noopener noreferrer" className="text-blue-500 hover:underline">
                                {conteudo.titulo} ({conteudo.tipo})
                            </a>
                        </li>
                    ))}
                </ul>
            ) : (
                <p className="mt-2">Não há conteúdos disponíveis para este roadmap.</p>
            )}
        </div>
    );
};

export default RoadmapPage;
```

### Alterações e Justificativas:

1. **Validação do `roadmapId`**: Adicionei uma verificação para garantir que o `roadmapId` seja um ID no formato hexadecimal antes de fazer a chamada para a API, evitando chamadas desnecessárias.

2. **Tratamento de Erros**: Melhorei o tratamento de erros, incluindo a mensagem de erro original retornada pela API, se disponível. Isso ajuda a identificar problemas específicos durante a chamada.

3. **Verificação de Conteúdos**: Antes de tentar mapear os conteúdos, agora verifico se `roadmap.conteudos` existe e se há conteúdos disponíveis. Isso evita erros de tempo de execução caso a propriedade esteja ausente ou vazia.

4. **Mensagem em caso de ausência de conteúdos**: Caso não haja conteúdos disponíveis, uma mensagem informativa é exibida, melhorando a experiência do usuário.