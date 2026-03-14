import supabase from '../supabase_client';
import { User } from '../types/User';
import bcrypt from 'bcrypt';
import { validate as validateEmail } from 'email-validator';

class UserService {
    private static instance: UserService;

    private constructor() {}

    public static getInstance(): UserService {
        if (!UserService.instance) {
            UserService.instance = new UserService();
        }
        return UserService.instance;
    }

    public async signUp(params: { nome: string; email: string; senha: string; plano_assinatura?: string; }): Promise<{ id: string; nome: string; email: string; }> {
        const { nome, email, senha, plano_assinatura } = params;

        // Validations
        if (!nome || !email || !senha) {
            throw new Error('Nome, email e senha são obrigatórios.');
        }

        if (!validateEmail(email)) {
            throw new Error('Formato de email inválido.');
        }

        if (senha.length < 8) {
            throw new Error('A senha deve ter pelo menos 8 caracteres e incluir letras e números.');
        }

        const hashedPassword = await bcrypt.hash(senha, 10);
        const { data, error } = await supabase
            .from('usuarios')
            .insert([{ nome, email, senha: hashedPassword, plano_assinatura }])
            .single();

        if (error) {
            if (error.code === '23505') {
                throw new Error('Email já cadastrado.');
            }
            throw new Error('Erro ao criar usuário: ' + error.message);
        }

        return { id: data.id, nome: data.nome, email: data.email };
    }

    public async login(params: { email: string; senha: string; }): Promise<{ token: string; user: User; }> {
        const { email, senha } = params;

        // Validations
        if (!email || !senha) {
            throw new Error('Email e senha são obrigatórios.');
        }

        const { data, error } = await supabase
            .from('usuarios')
            .select('*')
            .eq('email', email)
            .single();

        if (error || !data) {
            throw new Error('Credenciais inválidas.');
        }

        const isPasswordValid = await bcrypt.compare(senha, data.senha);
        if (!isPasswordValid) {
            throw new Error('Credenciais inválidas.');
        }

        const token = 'gerar-um-token-jwt-aqui'; 
        return { token, user: data as User };
    }

    public async getUser(params: { userId: string; }): Promise<User> {
        const { userId } = params;

        const { data, error } = await supabase
            .from('usuarios')
            .select('*')
            .eq('id', userId)
            .single();

        if (error || !data) {
            throw new Error('Usuário não encontrado ou acesso não autorizado.');
        }

        return data as User;
    }
}

export default UserService.getInstance();