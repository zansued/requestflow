import React, { useState } from 'react';
import { User } from '../types/User';
import { RegisterForm } from '../types/RegisterForm';
import userService from '../services/userService';
import { toast } from 'react-toastify';

const Register: React.FC = () => {
    const [formData, setFormData] = useState<RegisterForm>({ nome: '', email: '', password: '' });
    const [errors, setErrors] = useState<{ nome?: string; email?: string; password?: string }>({});

    const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        setFormData({ ...formData, [e.target.name]: e.target.value });
    };

    const validateForm = () => {
        const newErrors: { nome?: string; email?: string; password?: string } = {};
        if (formData.nome.length < 2) {
            newErrors.nome = 'O nome deve ter pelo menos 2 caracteres';
        }
        const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailPattern.test(formData.email)) {
            newErrors.email = 'O email deve ser válido';
        }
        if (formData.password.length < 6) {
            newErrors.password = 'A senha deve ter pelo menos 6 caracteres e incluir letras e números';
        }
        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    };

    const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        if (!validateForm()) {
            return;
        }

        try {
            await userService.createUser(formData);
            toast.success('Usuário registrado com sucesso!');
            setFormData({ nome: '', email: '', password: '' });
        } catch (error) {
            if (error.response?.status === 409) {
                toast.error('O email já está em uso.');
            } else {
                toast.error('Ocorreu um erro ao tentar registrar. Tente novamente mais tarde.');
            }
        }
    };

    return (
        <form onSubmit={handleSubmit} className="flex flex-col space-y-4">...
    );
};

export default Register;