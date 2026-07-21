import React from 'react';
import FontAwesome from '@expo/vector-icons/FontAwesome';
import { Tabs } from 'expo-router';
import { colors } from '@/components/nyt-design-system';
import { useColorScheme } from '@/components/useColorScheme';

function TabBarIcon(props: {
  name: React.ComponentProps<typeof FontAwesome>['name'];
  color: string;
}) {
  return <FontAwesome size={22} style={{ marginBottom: -3 }} {...props} />;
}

export default function TabLayout() {
  const colorScheme = useColorScheme();

  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: colors.wirecutter.blue,
        tabBarInactiveTintColor: colors.secondary,
        tabBarStyle: {
          backgroundColor:
            colorScheme === 'dark' ? colors.primary : colors.background,
          borderTopColor: colors.surface,
        },
        headerStyle: {
          backgroundColor:
            colorScheme === 'dark' ? colors.primary : colors.background,
        },
        headerTintColor:
          colorScheme === 'dark' ? colors.background : colors.primary,
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Picks',
          tabBarIcon: ({ color }) => <TabBarIcon name="star" color={color} />,
        }}
      />
      <Tabs.Screen
        name="deals"
        options={{
          title: 'Deals',
          tabBarIcon: ({ color }) => <TabBarIcon name="tag" color={color} />,
        }}
      />
      <Tabs.Screen
        name="lists"
        options={{
          title: 'Lists',
          tabBarIcon: ({ color }) => (
            <TabBarIcon name="list-ul" color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="categories"
        options={{
          title: 'Categories',
          tabBarIcon: ({ color }) => (
            <TabBarIcon name="th-large" color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="search"
        options={{
          title: 'Search',
          tabBarIcon: ({ color }) => <TabBarIcon name="search" color={color} />,
        }}
      />
    </Tabs>
  );
}
