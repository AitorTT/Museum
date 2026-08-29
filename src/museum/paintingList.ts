// Flat replacement for Godot's per-room folder scan (MuseumBuilder._load_paintings).
// Order matches the staged MUSEUM_JS/PAINTINGS listing; paintings are assigned
// to eligible rooms sequentially until the list runs out.
export const PAINTING_FILES: string[] = [
  '1914.1018 - Love of Winter.jpg',
  '1924.127 - Woman at Her Toilette.jpg',
  '1926.220 - Woman before an Aquarium.jpg',
  '1926.224 - A Sunday on La Grande Jatte — 1884.jpg',
  '1926.252 - The Basket of Apples.jpg',
  '1926.417 - The Bedroom.jpg',
  '1928.1086 - Under the Wave off Kanagawa (Kanagawa oki nami....jpg',
  '1931.511 - Improvisation No. 30 (Cannons).jpg',
  '1933.1157 - Water Lilies.jpg',
  '1964.336 - Paris Street; Rainy Day.jpg',
  '1968.88 - A City Park.jpg',
  '1977.157 - Autumn Maples with Poem Slips.jpg',
  '1982.802 - The Advance-Guard, or The Military Sacrifice (The....jpg',
  '1990.165 - Flower Clouds.jpg',
  'Café Terrace at Night_1888.jpg',
  'Henri Georges J. I. Meunier (Belgian, 1873-1922) - L\'Heure du silence.jpg',
  'John Singer Sargent – Orestes Pursued by the Furies (Orestes Pursued by the Furies), 1921 .jpg',
  'Kandinsky Reitendes Paar.jpg',
  'Klimt hygeia.jpg',
  'Le Chat Noir_Théophile Steinlen\'s 1896 poster.jpg',
  'Mural by Beastman, Spotlight Sydenham, in Christchurch, Canterbury.jpg',
  'New York, the wonder city of the world - Travel by train - Adolph Treidler artwork.jpg',
  'Postcard from the Wiener Werkstatte No. 680 bulldog (1912) by Moriz Jung and Wiener Werkstatte. Vintage postcard, old illustration art print..jpg',
  'Preparatory design - Klimt - Stoclet Palace.jpg',
  'Takiyasha the Witch and the Skeleton Spectre.jpg',
  'Wheat Field with Cypresses 1889 Vincent van Gogh.jpg',
  'Winter Landscape in Moonlight (1919) painting in high resolution by Ernst Ludwig Kirchner..jpg',
];

export function paintingUrl(dir: string, fileName: string): string {
  return `${dir}/${encodeURI(fileName)}`;
}
