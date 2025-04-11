import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class RecipeCardShimmer extends StatelessWidget {
  final bool isHorizontal;
  
  const RecipeCardShimmer({
    super.key,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: isHorizontal ? _buildHorizontalShimmer() : _buildVerticalShimmer(),
      ),
    );
  }
  
  Widget _buildVerticalShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image placeholder
        Container(
          height: 140,
          color: Colors.white,
        ),
        
        // Content placeholders
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Container(
                width: double.infinity,
                height: 14,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Container(
                width: 150,
                height: 14,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              
              // Bottom row
              Row(
                children: [
                  const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 80,
                    height: 10,
                    color: Colors.white,
                  ),
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 10,
                    color: Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildHorizontalShimmer() {
    return Row(
      children: [
        // Image placeholder
        Container(
          width: 120,
          height: 120,
          color: Colors.white,
        ),
        
        // Content placeholders
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Container(
                  width: double.infinity,
                  height: 14,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Container(
                  width: 150,
                  height: 14,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                
                // Bottom row
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 10,
                      color: Colors.white,
                    ),
                    const Spacer(),
                    Container(
                      width: 40,
                      height: 10,
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}