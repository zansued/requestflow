import React, { useState } from 'react';
import { useDispatch } from 'react-redux';
import { loginUser } from '../services/userService';
import { LoginForm } from '../types/LoginForm';

const Login: React.FC = () => {
    const [formData, setFormData] = useState<LoginForm>({ email: '', password: '' });
    const [error, setError] = useState<string | null>(null);
    const [successMessage, setSuccessMessage] = useState<string | null>(null);
    const dispatch = useDispatch();

    const handleInputChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        const { name, value } = event.target;
        setFormData(prevState => ({...
    };

    const validateForm = () => {
        const { email, password } = formData;
        if (!/\S+@\S+\.\S+/.test(email)) {
            setError('Por favor, insira um email válido.');
            return false;
        }
        if (password.length < 6) {
            setError('A senha deve ter pelo menos 6 caracteres.');
            return false;
        }
        return true;
    };

    const handleLogin = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        if (!validateForm()) {
            return;
        }
        try {
            await dispatch(loginUser(formData));
            setSuccessMessage('Login bem-sucedido!');
        } catch (error) {
            setError("Erro ao fazer login. Verifique suas credenciais e tente novamente.");
            console.error("Erro ao fazer login:", error);
        }
    };

    return (
        <form className="flex flex-col space-y-4" onSubmit={handleLogin}>...
    );
};

export default Login;