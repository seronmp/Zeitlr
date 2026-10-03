import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).end();

  const { email, password } = req.body;

  try {
    const { rows } = await pool.query(
      'SELECT id, email, display_name FROM users WHERE email = $1 AND password = $2',
      [email, password]
    );

    if (rows.length === 0) {
      return res.status(401).json({ error: 'E-Mail oder Passwort falsch' });
    }

    // Restituisce i dati dell'utente loggato
    return.status(200).json({ user: rows[0] });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message });
  }
}
