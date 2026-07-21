import { GraphQLClient } from "graphql-request";
import { GET_PRODUCT_CARDS, GET_SCOOP_PRODUCT_CARDS } from "./queries.js";
import type {
  GetProductCardsResponse,
  GetScoopProductCardsResponse,
  MinotaurProductCard,
} from "../types/minotaur.js";

const MINOTAUR_URL =
  process.env.MINOTAUR_GRAPHQL_URL ?? "https://minotaur.wirecutter.com/graphql";

const client = new GraphQLClient(MINOTAUR_URL, {
  headers: {
    ...(process.env.MINOTAUR_API_KEY && {
      Authorization: `Bearer ${process.env.MINOTAUR_API_KEY}`,
    }),
  },
});

export async function getProductCards(
  postIds: number[]
): Promise<MinotaurProductCard[]> {
  const data = await client.request<GetProductCardsResponse>(
    GET_PRODUCT_CARDS,
    { postIds }
  );
  return data.getProductCards;
}

export async function getScoopProductCards(
  postIds: number[]
): Promise<MinotaurProductCard[]> {
  const data = await client.request<GetScoopProductCardsResponse>(
    GET_SCOOP_PRODUCT_CARDS,
    { postIds }
  );
  return data.getScoopProductCards;
}
