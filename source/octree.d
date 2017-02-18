import intersection;
import renderer;
import std.math: abs, cos, PI, sin, sqrt;
import std.random: uniform;
import std.stdio;
import vec3;

// Generation code adapted from http://cg.alexandra.dk/?p=3836

int nextPowerOfTwo( int x )
{
    if (x < 0)
    {
        return 0;
    }

    --x;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    
    return x + 1;
}

private enum NodeType
{
    Internal,
    EmptyLeaf,
    Leaf
}

private class OctreeNode
{
    public OctreeNode[ 8 ] children;
    public Aabb buildAabb;
    public Aabb worldAabb;
    public NodeType nodeType;
    public float distanceToSurface;
}

public Vec3 uniformSphericalSampling( float u, float v )
{
    const float phi = v * 2 * PI;
    const float cosTheta = 1 - u;
    const float sinTheta = sqrt( 1 - cosTheta * cosTheta );
    return Vec3( cos( phi ) * sinTheta, sin( phi ) * sinTheta, cosTheta );
}

public class Octree
{
    this( Vertex[] vertices, Face[] indices, float voxelSize, float borderSize )
    {
        assert( voxelSize > 0, "voxel dimension is 0" );

        this.voxelSize = voxelSize;
        
        Vertex[] flattenedVertices = new Vertex[ indices.length * 3 ];
        flattenVertices( vertices, indices, flattenedVertices );

        Aabb meshAabb = getMeshAABB( flattenedVertices );

        for (int dirIndex = 0; dirIndex < 200; ++dirIndex)
        {
            float x = dirIndex / 200.0f;
            float y = uniform( 0, 100 ) / 100.0f;
            sampleDirections ~= uniformSphericalSampling( x, y );
        }

        // 1. Scales the AABB to find the correct octree dimension.
        meshAabb.min.x *= (1.0f / voxelSize);
        meshAabb.min.y *= (1.0f / voxelSize);
        meshAabb.min.z *= (1.0f / voxelSize);
        meshAabb.max.x *= (1.0f / voxelSize);
        meshAabb.max.y *= (1.0f / voxelSize);
        meshAabb.max.z *= (1.0f / voxelSize);

        //writeln("min AABB: ", meshAABBMin.x, ", ", meshAABBMin.y, ", ", meshAABBMin.z );
        //writeln("max AABB: ", meshAABBMax.x, ", ", meshAABBMax.y, ", ", meshAABBMax.z );

        // 2. Finds the longest axis.
        Vec3 dim = meshAabb.max - meshAabb.min;
        octreeDim = nextPowerOfTwo( cast(int)( dim.maxComponent() + borderSize ) );
        writeln("octreeDim: ", octreeDim);

        float worldSize = octreeDim * voxelSize;
        octreeOrigin = meshAabb.getCenter() - Vec3( worldSize / 2, worldSize / 2, worldSize / 2 );
        writeln("octreeOrigin: ", octreeOrigin.x, ", ", octreeOrigin.y, ", ", octreeOrigin.z );

        // 3. Creates the octree root.
        Vec3 rootAABBMin = octreeOrigin;
        Vec3 rootAABBMax = octreeOrigin + Vec3( worldSize, worldSize, worldSize );

        // 4. Subdivision
        rootNode = new OctreeNode();
        rootNode.worldAabb.min = rootAABBMin;
        rootNode.worldAabb.max = rootAABBMax;
        rootNode.buildAabb.min = Vec3( 0, 0, 0 );
        rootNode.buildAabb.max = Vec3( octreeDim, octreeDim, octreeDim ); 

        subdivide( rootNode, vertices, indices );
        const float minCoverage = 0.9f;
        updateInternalEmptyLeafsSign( rootNode, rootNode, minCoverage );
    }

    public Vec3[] getLines()
    {
        Vec3[] lines;
        getNodeLines( rootNode, lines );

        return lines;
    }

    private Vec3[] getNodeLines( OctreeNode node, ref Vec3[] lines )
    {
        if (!(node is null) && node.nodeType != NodeType.EmptyLeaf)
        //if (!(node is null) && node.nodeType != NodeType.Leaf)
        //if (!(node is null) && node.nodeType != NodeType.Internal)
        {
            lines ~= node.worldAabb.getLines();

            for (int childIndex = 0; childIndex < 8; ++childIndex)
            {
                getNodeLines( node.children[ childIndex ], lines );
            }
        }

        return lines;
    }

    private bool rayOctreeIntersection( Vec3 rayOrigin, Vec3 rayDirection, OctreeNode node )
    {
        if (node is null)
        {
            return false;
        }

        if (node.nodeType == NodeType.Leaf)
        {
            return rayBoxIntersection( rayOrigin, rayDirection, node.worldAabb );
        }

        if (node.nodeType == NodeType.Internal)
        {
            if (rayBoxIntersection( rayOrigin, rayDirection, node.worldAabb ))
            {
                for (int childIndex = 0; childIndex < 8; ++childIndex)
                {
                    if (rayOctreeIntersection( rayOrigin, rayDirection, node.children[ childIndex ] ))
                    {
                        return true;
                    }
                }
            }
            else
            {
                return false;
            }
        }

        return false;
    }

    private void updateInternalEmptyLeafsSign( OctreeNode rootNode, OctreeNode node, float minCoverage )
    {
        if (node is null)
        {
            return;
        }

        if (node.nodeType == NodeType.Leaf)
        {
            // The sign has already been updated during octree building
            return;
        }

        if (node.nodeType == NodeType.Internal)
        {
            for (int childIndex = 0; childIndex < 8; ++childIndex)
            {
                updateInternalEmptyLeafsSign( rootNode, node.children[ childIndex ], minCoverage );
            }

            return;
        }

        int coverage = 0;
        int misses = 0;
        const int sampleDirectionsLength = 200;
        int maxMisses = sampleDirectionsLength / 4;

        for (int sampleDirectionIndex = 0; sampleDirectionIndex < sampleDirectionsLength; ++sampleDirectionIndex)
        {
            Vec3 rayOrigin = node.worldAabb.getCenter();
            Vec3 rayDirection = sampleDirections[ sampleDirectionIndex ];

            if (rayOctreeIntersection( rayOrigin, rayDirection, node ))
            {
                ++coverage;
            }
            else
            {
                ++misses;
            }

            if (misses >= maxMisses)
            {
                break;
            }
        }

        const float fCoverage = coverage / cast(float)sampleDirectionsLength;

        node.distanceToSurface = (fCoverage >= minCoverage) ? -1 : 1;
    }

    private void subdivide( OctreeNode parentNode, Vertex[] vertices, Face[] nodeTriangleIndices )
    {
        uint childIndex = 0;
        int aabbDim = cast(int)( (parentNode.buildAabb.max.x - parentNode.buildAabb.min.x) / 2 );
        assert( aabbDim > 0, "invalid aabb dim" );

        for (int z = 0; z < 2; ++z)
        {
            for (int y = 0; y < 2; ++y)
            {
                for (int x = 0; x < 2; ++x)
                {
                    OctreeNode childNode = new OctreeNode();
                    childNode.buildAabb.min = parentNode.buildAabb.min + Vec3( aabbDim * x, aabbDim * y, aabbDim * z );
                    childNode.buildAabb.max = childNode.buildAabb.min + Vec3( aabbDim, aabbDim, aabbDim );
                    parentNode.children[ childIndex ] = childNode;
                    ++childIndex;
                }
            }
        }

        // Subdivides the node.
        for (childIndex = 0; childIndex < 8; ++childIndex)
        {
            OctreeNode childNode = parentNode.children[ childIndex ];
            int[] childTriangleIndices;
            Face[] childTriangles;

            childNode.worldAabb.min = octreeOrigin + childNode.buildAabb.min * voxelSize;
            childNode.worldAabb.max = octreeOrigin + childNode.buildAabb.max * voxelSize;

            for (int faceIndex = 0; faceIndex < nodeTriangleIndices.length; ++faceIndex)
            {
                Vec3[ 3 ] triangleVertices;
                
                float[ 3 ] pos = vertices[ nodeTriangleIndices[ faceIndex ].a ].pos;
                triangleVertices[ 0 ] = Vec3( pos[ 0 ], pos[ 1 ], pos[ 2 ] );

                pos = vertices[ nodeTriangleIndices[ faceIndex ].b ].pos;
                triangleVertices[ 1 ] = Vec3( pos[ 0 ], pos[ 1 ], pos[ 2 ] );

                pos = vertices[ nodeTriangleIndices[ faceIndex ].c ].pos;
                triangleVertices[ 2 ] = Vec3( pos[ 0 ], pos[ 1 ], pos[ 2 ] );

                if (triangleIntersectsAABB( triangleVertices, childNode.worldAabb ))
                {
                    childTriangleIndices ~= faceIndex;
                    childTriangles ~= nodeTriangleIndices[ faceIndex ];
                }
            }

            // No intersections so this child is empty
            if (childTriangleIndices.length == 0)
            {
                childNode.nodeType = NodeType.EmptyLeaf;
                //writeln( "node: empty leaf" );
            }
            else
            {
                // Got a leaf node
                if (aabbDim == 1)
                {
                    childNode.nodeType = NodeType.Leaf;
                    //writeln( "node: leaf" );
                    updateLeafNodeDistanceValue( childNode, vertices, childTriangleIndices );
                }
                else
                {
                    childNode.nodeType = NodeType.Internal;
                    //writeln( "node: internal" );
                    subdivide( childNode, vertices, childTriangles );
                }
            }
        }
    }

    private void updateLeafNodeDistanceValue( OctreeNode leafNode, Vertex[] vertices, int[] faces ) @nogc
    {
        float minDistance = float.max;

        for (int faceIndex = 0; faceIndex < faces.length; ++faceIndex)
        {
            Vec3[ 3 ] triangleVerts;
            triangleVerts[ 0 ] = Vec3( vertices[ faceIndex + 0 ].pos[ 0 ], vertices[ faceIndex + 0 ].pos[ 1 ], vertices[ faceIndex + 0 ].pos[ 2 ] );
            triangleVerts[ 1 ] = Vec3( vertices[ faceIndex + 1 ].pos[ 0 ], vertices[ faceIndex + 1 ].pos[ 1 ], vertices[ faceIndex + 1 ].pos[ 2 ] );
            triangleVerts[ 2 ] = Vec3( vertices[ faceIndex + 2 ].pos[ 0 ], vertices[ faceIndex + 2 ].pos[ 1 ], vertices[ faceIndex + 2 ].pos[ 2 ] );

            const Vec3 normal = cross( triangleVerts[ 2 ] - triangleVerts[ 0 ], triangleVerts[ 1 ] - triangleVerts[ 0 ] );
            const Vec3 closestPoint = closestPointOnTriangle( triangleVerts, leafNode.worldAabb, leafNode.worldAabb.getCenter() );
            Vec3 delta = closestPoint - leafNode.worldAabb.getCenter();
            const float sign = (dot( delta, normal ) < 0) ? -1 : 1;
            float distance = length( delta );

            if (distance < abs( minDistance ))
            {
                minDistance = distance * sign;
            }
        }

        leafNode.distanceToSurface = minDistance;
    }

    private void flattenVertices( Vertex[] vertices, Face[] indices, out Vertex[] flattenedVertices )
    {
        foreach (face; indices)
        {
            flattenedVertices ~= vertices[ face.a ];
            flattenedVertices ~= vertices[ face.b ];
            flattenedVertices ~= vertices[ face.c ];
        }
    }

    private static Aabb getMeshAABB( Vertex[] vertices )
    {
        Vec3 meshAABBMin = Vec3( int.max, int.max, int.max );
        Vec3 meshAABBMax = Vec3( int.min, int.min, int.min );

        foreach(vertex; vertices)
        {
            if (vertex.pos[ 0 ] < meshAABBMin.x)
            {
                meshAABBMin.x = vertex.pos[ 0 ];
            }
            if (vertex.pos[ 1 ] < meshAABBMin.y)
            {
                meshAABBMin.y = vertex.pos[ 1 ];
            }
            if (vertex.pos[ 2 ] < meshAABBMin.z)
            {
                meshAABBMin.z = vertex.pos[ 2 ];
            }

            if (vertex.pos[ 0 ] > meshAABBMax.x)
            {
                meshAABBMax.x = vertex.pos[ 0 ];
            }
            if (vertex.pos[ 1 ] > meshAABBMax.y)
            {
                meshAABBMax.y = vertex.pos[ 1 ];
            }
            if (vertex.pos[ 2 ] > meshAABBMax.z)
            {
                meshAABBMax.z = vertex.pos[ 2 ];
            }
        }

        return Aabb( meshAABBMin, meshAABBMax );
    }

    private float voxelSize;
    private int octreeDim;
    private Vec3 octreeOrigin;
    private Vec3[] sampleDirections;
    private OctreeNode rootNode;
}

unittest
{
    assert( nextPowerOfTwo( 1 ) == 1, "nextPowerOfTwo with param 1 failed" );
    assert( nextPowerOfTwo( 3 ) == 4, "nextPowerOfTwo with param 3 failed" );
    assert( nextPowerOfTwo( 4 ) == 4, "nextPowerOfTwo with param 4 failed" );

    //Vertex[3] vertices;
    //Aabb aabb = getMeshAABB( vertices );
    //assert( );
}
