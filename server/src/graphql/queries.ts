import { gql } from "graphql-request";

export const GET_PRODUCT_CARDS = gql`
  query GetProductCards($postIds: [Int!]!) {
    getProductCards(postIds: $postIds) {
      postId
      postType
      productId
      referenceId
      title
      description
      pickTypeId
      ribbon
      hideRibbon
      article {
        postId
        postType
        title
        link
        modifiedDate
      }
      product {
        id
        name
        images
        hasDealData
        sources {
          id
          price {
            raw
            formatted
          }
          merchant {
            name
            affiliateLink
          }
          dealData {
            affiliateLink
            promoCode
            promoEffect
            price {
              raw
              formatted
            }
            streetPrice {
              raw
              formatted
            }
          }
        }
      }
    }
  }
`;

export const GET_SCOOP_PRODUCT_CARDS = gql`
  query GetScoopProductCards($postIds: [Int!]!) {
    getScoopProductCards(postIds: $postIds) {
      postId
      postType
      productId
      referenceId
      title
      description
      pickTypeId
      ribbon
      hideRibbon
      article {
        postId
        postType
        title
        link
        modifiedDate
      }
      product {
        id
        name
        images
        hasDealData
        sources {
          id
          price {
            raw
            formatted
          }
          merchant {
            name
            affiliateLink
          }
          dealData {
            affiliateLink
            promoCode
            promoEffect
            price {
              raw
              formatted
            }
            streetPrice {
              raw
              formatted
            }
          }
        }
      }
    }
  }
`;
