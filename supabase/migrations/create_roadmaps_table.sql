CREATE TABLE IF NOT EXISTS roadmaps (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    usuarioId uuid NOT NULL,
    titulo text NOT NULL,
    descricao text,
    CONSTRAINT fk_usuario
        FOREIGN KEY (usuarioId) 
        REFERENCES usuarios(id)
        ON DELETE CASCADE
);

CREATE POLICY roadmap_select_policy ON roadmaps
FOR SELECT
USING (auth.uid() = usuarioId);

CREATE POLICY roadmap_insert_policy ON roadmaps
FOR INSERT
WITH CHECK (auth.uid() = usuarioId);

CREATE POLICY roadmap_update_policy ON roadmaps
FOR UPDATE
USING (auth.uid() = usuarioId);

CREATE POLICY roadmap_delete_policy ON roadmaps
FOR DELETE
USING (auth.uid() = usuarioId);