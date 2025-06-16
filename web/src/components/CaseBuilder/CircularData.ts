export interface CircularPlant {
    id: string;
    x: number;
    y: number;


}

export interface CircularProduct { 
    id: string;
    x: number;
    y: number;
}

export interface CircularData {
    plants: Record<string, CircularPlant>;

    products: Record<string, CircularProduct>;


}