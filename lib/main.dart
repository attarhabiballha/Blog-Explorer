import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => BlogProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Blog App',
      initialRoute: '/',
      routes: {
        '/': (context) => BlogListScreen(),
        '/categories': (context) => CategoriesScreen(),
        '/favorite_blogs': (context) => FavoriteBlogsScreen(),
      },
    );
  }
}

class BlogProvider extends ChangeNotifier {
  List<Blog> _blogs = [];
  Map<String, bool> _likedBlogs = {};

  List<Blog> get blogs => _blogs;
  Map<String, bool> get likedBlogs => _likedBlogs;

  BlogProvider() {
    fetchBlogs();
  }

  Future<void> fetchBlogs() async {
    final String url = 'https://dev.to/api/articles?per_page=10';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        _blogs = responseData.map((data) {
          return Blog(
            id: data['id'].toString(),
            title: data['title'] ?? '',
            body: data['description'] ?? '',
            imageUrl: data['cover_image'] ?? 'https://via.placeholder.com/150',
            categories: data['tag_list'].cast<String>(),
          );
        }).toList();
        notifyListeners();
      } else {
        throw Exception('Failed to load blogs');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void toggleFavorite(String id) {
    if (_likedBlogs.containsKey(id)) {
      _likedBlogs[id] = !_likedBlogs[id]!;
    } else {
      _likedBlogs[id] = true;
    }
    notifyListeners();
  }
}

class BlogListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final blogProvider = Provider.of<BlogProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Blog Posts'),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'categories') {
                Navigator.pushNamed(context, '/categories');
              } else if (value == 'favorites') {
                Navigator.pushNamed(context, '/favorite_blogs');
              }
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'categories',
                  child: Text('Categories'),
                ),
                PopupMenuItem<String>(
                  value: 'favorites',
                  child: Text('Favorites'),
                ),
              ];
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: blogProvider.blogs.length,
        itemBuilder: (context, index) {
          final blog = blogProvider.blogs[index];
          final isLiked = blogProvider.likedBlogs.containsKey(blog.id) && blogProvider.likedBlogs[blog.id]!;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailedBlogView(blog: blog),
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                        child: Image.network(
                          blog.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        blog.title,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Categories: ${blog.categories.join(", ")}',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : null,
                          ),
                          onPressed: () {
                            blogProvider.toggleFavorite(blog.id);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DetailedBlogView extends StatelessWidget {
  final Blog blog;

  DetailedBlogView({required this.blog});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(blog.title),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              blog.body,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoriesScreen extends StatefulWidget {
  @override
  _CategoriesScreenState createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String? selectedCategory;

  @override
  Widget build(BuildContext context) {
    final blogProvider = Provider.of<BlogProvider>(context);
    final categories = blogProvider.blogs.expand((blog) => blog.categories).toSet().toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Categories'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: CategoriesList(
              categories: categories,
              selectedCategory: selectedCategory,
              onSelectCategory: (category) {
                setState(() {
                  if (selectedCategory == category) {
                    selectedCategory = null;
                  } else {
                    selectedCategory = category;
                  }
                });
              },
            ),
          ),
          Expanded(
            child: BlogsByCategoryScreen(
              category: selectedCategory,
              blogProvider: blogProvider,
            ),
          ),
        ],
      ),
    );
  }
}

class BlogsByCategoryScreen extends StatelessWidget {
  final String? category;
  final BlogProvider blogProvider;

  BlogsByCategoryScreen({required this.category, required this.blogProvider});

  @override
  Widget build(BuildContext context) {
    List<Blog> blogsByCategory = [];

    if (category != null) {
      blogsByCategory = blogProvider.blogs.where((blog) => blog.categories.contains(category)).toList();
    } else {
      blogsByCategory = blogProvider.blogs;
    }

    return ListView.builder(
      itemCount: blogsByCategory.length,
      itemBuilder: (context, index) {
        final blog = blogsByCategory[index];
        final isLiked = blogProvider.likedBlogs.containsKey(blog.id) && blogProvider.likedBlogs[blog.id]!;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailedBlogView(blog: blog),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                      child: Image.network(
                        blog.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      blog.title,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Categories: ${blog.categories.join(", ")}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : null,
                        ),
                        onPressed: () {
                          blogProvider.toggleFavorite(blog.id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CategoriesList extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final Function(String) onSelectCategory;

  CategoriesList({
    required this.categories,
    required this.selectedCategory,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                primary: selectedCategory == category ? Colors.blue : Colors.white,
              ),
              onPressed: () {
                onSelectCategory(category);
              },
              child: Text(
                category.toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  color: selectedCategory == category ? Colors.white : Colors.black,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FavoriteBlogsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final blogProvider = Provider.of<BlogProvider>(context);
    final likedBlogs = blogProvider.likedBlogs;
    final favoriteBlogs = blogProvider.blogs.where((blog) => likedBlogs.containsKey(blog.id) && likedBlogs[blog.id]!).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Favorite Blogs'),
      ),
      body: ListView.builder(
        itemCount: favoriteBlogs.length,
        itemBuilder: (context, index) {
          final blog = favoriteBlogs[index];
          final isLiked = blogProvider.likedBlogs.containsKey(blog.id) && blogProvider.likedBlogs[blog.id]!;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailedBlogView(blog: blog),
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                        child: Image.network(
                          blog.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        blog.title,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Categories: ${blog.categories.join(", ")}',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : null,
                          ),
                          onPressed: () {
                            blogProvider.toggleFavorite(blog.id);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class Blog {
  final String id;
  final String title;
  final String body;
  String imageUrl;
  final List<String> categories;

  Blog({
    required this.id,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.categories,
  });
}
