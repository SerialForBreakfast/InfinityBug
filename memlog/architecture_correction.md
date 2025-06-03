# EPG Architecture Correction

## ❌ **Current Wrong Implementation**
- **Section**: Each individual channel (80 sections total)
- **Items**: Listings within each channel
- **Problem**: This creates too many sections and doesn't group by genre properly

## ✅ **Correct EPG Architecture**
- **Section**: Each genre category (8 sections total: Horror, Comedy, Drama, Sports, Kids, Documentary, News, Music)
- **Items**: All listings from all channels within that genre
- **Layout**: Horizontal scrolling within each genre section, with channel headers

## **Data Structure Changes Needed**

### Current (Wrong):
```swift
private var epgDataSource: UICollectionViewDiffableDataSource<Channel, Listing>!
// Creates 80 sections (one per channel)
```

### Correct:
```swift
private var epgDataSource: UICollectionViewDiffableDataSource<Genre, Listing>!
// Creates 8 sections (one per genre)
```

## **Layout Structure**
```
Section 0: Horror
├── Horror Channel 1 Header
├── [Listing 1] [Listing 2] [Listing 3] ...
├── Horror Channel 2 Header  
├── [Listing 1] [Listing 2] [Listing 3] ...
└── ... (all Horror channels)

Section 1: Comedy
├── Comedy Channel 1 Header
├── [Listing 1] [Listing 2] [Listing 3] ...
└── ... (all Comedy channels)

Section 2: Drama
└── ... (all Drama channels)
```

## **Implementation Changes Required**

1. **Data Source Type**: Change from `<Channel, Listing>` to `<Genre, Listing>`
2. **Snapshot Population**: Group listings by genre instead of by channel
3. **Layout Logic**: Adjust to handle multiple channels per section
4. **Header Management**: Show channel headers within genre sections
5. **Focus Management**: Update to work with genre-based sections

## **Benefits of Correct Architecture**
- ✅ Proper genre grouping
- ✅ Fewer sections (8 instead of 80)
- ✅ More logical navigation
- ✅ Better performance
- ✅ Matches typical EPG design patterns

---
*Status: Architecture Understanding Corrected - Ready for Implementation* 